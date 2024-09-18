# Copyright Vespa.ai. All rights reserved.

import argparse
import json
import pandas as pd
import re
import sys

cpu_cores = 1

def get_cpu(metrics):
    regex = re.compile(r'\["cpuutil", "[^"]+"\]')
    for key, value in metrics.items():
        if regex.match(key):
            return float(value) * cpu_cores
    return 0.0


def load_feed_results(file_name, system):
    df = pd.DataFrame(columns=['system', 'label', 'throughput', 'cpu', 'throughput_per_cpu'])
    with open(file_name, 'r') as file:
        for line in file.readlines():
            obj = json.loads(line)
            p = obj['parameters']
            m = obj['metrics']
            if not 'query_phase' in p:
                throughput = float(m['feeder.throughput'])
                cpu = get_cpu(m)
                df.loc[len(df.index)] = [system, p['label'], throughput, cpu, throughput / cpu]
    df.sort_values(by='label', inplace=True)
    return df


def load_query_results(file_name, system, query_filter):
    df = pd.DataFrame(columns=['system', 'phase', 'type', 'filter', 'clients', 'l_avg', 'l_99p', 'qps', 'cpu', 'qps_per_cpu'])
    with open(file_name, 'r') as file:
        for line in file.readlines():
            obj = json.loads(line)
            p = obj['parameters']
            m = obj['metrics']
            if 'query_phase' in p:
                phase = p['query_phase']
                type = p['query_type']
                is_filter = type.endswith('_filter')
                qps = float(m['qps'])
                cpu = get_cpu(m)
                if system == 'es' and phase == 'after_merge':
                    # Rename to match equivalent Vespa phase
                    phase = 'after_flush'
                df.loc[len(df.index)] = [system, phase, type, is_filter, int(p['clients']),
                                         float(m['avgresponsetime']), float(m['99 percentile']), qps, cpu, qps / cpu]
                if system == 'es' and phase == 'after_feed':
                    # We need this entry to compare with 'after_flush' for Vespa
                    df.loc[len(df.index)] = [system, 'after_flush', type, is_filter, int(p['clients']),
                                             float(m['avgresponsetime']), float(m['99 percentile']), qps, cpu, qps / cpu]

    df.sort_values(by=['phase', 'type', 'clients'], inplace=True)
    df = df.query(query_filter)
    df = df.reset_index(drop=True)
    return df


def feed_ratio_summary(v, e):
    assert(len(v) == len(e))
    # Ratio numbers > 1 : In favor of Vespa
    r = pd.DataFrame(index=v.index, columns=v.columns)
    r.system = 'ratio'
    r.label = v.label
    r.throughput = v.throughput / e.throughput
    r.cpu = e.throughput / v.throughput
    r.throughput_per_cpu = v.throughput_per_cpu / e.throughput_per_cpu
    return r


def query_ratio_summary(v, e):
    assert(len(v) == len(e))
    # Ratio numbers > 1 : In favor of Vespa
    r = pd.DataFrame(index=v.index, columns=v.columns)
    r.system = 'ratio'
    r.phase = v.phase
    r.type = v.type
    r['filter'] = v['filter']
    r.clients = v.clients
    r.l_avg = e.l_avg / v.l_avg
    r.l_99p = e.l_99p / v.l_99p
    r.qps = v.qps / e.qps
    r.cpu = e.cpu / v.cpu
    r.qps_per_cpu = v.qps_per_cpu / e.qps_per_cpu
    return r


def print_summary(v, e, r, format):
    if format == 'csv':
        v.to_csv(sys.stdout, index=False, float_format='%.3f')
        e.to_csv(sys.stdout, index=False, float_format='%.3f')
        r.to_csv(sys.stdout, index=False, float_format='%.3f')
    else:
        print(v)
        print(e)
        print(r)


def print_feed_ratio_summary(vespa_file, es_file, format):
    v = load_feed_results(vespa_file, "vespa")
    e = load_feed_results(es_file, "es")
    r = feed_ratio_summary(v, e)
    print_summary(v, e, r, format)


def print_query_ratio_summary(vespa_file, es_file, query_filter, format):
    v = load_query_results(vespa_file, "vespa", query_filter)
    e = load_query_results(es_file, "es", query_filter)
    r = query_ratio_summary(v, e)
    print_summary(v, e, r, format)


def main():
    parser = argparse.ArgumentParser(description="Tool that summarizes feed and query results "
                                                 "between Vespa and ES runs of the performance test")
    # How to use:
    # The results of a performance test run are logged as JSON in the test log output under:
    # '#### Performance results ####'
    # Create a file with these results, one JSON object (per line) per data sample.
    parser.add_argument('vespa_file', type=str, help='Path to Vespa result file')
    parser.add_argument('es_file', type=str, help='Path to ES result file')
    parser.add_argument('report_type',
                        choices=['feed', 'query_1', 'query_n', 'query_n_filter', 'query_n_refeed'],
                        help='Type of report to create')
    parser.add_argument('--format', default='df', choices=['csv', 'df'], help='Output format printed to stdout')
    parser.add_argument('--cpus', default=128, help='The number of CPUs used for the performance tests')

    args = parser.parse_args()
    report = args.report_type
    global cpu_cores
    cpu_cores = int(args.cpus)
    if report == 'feed':
        print_feed_ratio_summary(args.vespa_file, args.es_file, args.format)
    elif report == 'query_1':
        print_query_ratio_summary(args.vespa_file, args.es_file,
                                  "clients == 1", args.format)
    elif report == 'query_n':
        print_query_ratio_summary(args.vespa_file, args.es_file,
                                  "phase == 'after_flush' and filter == False",
                                  args.format)
    elif report == 'query_n_filter':
        print_query_ratio_summary(args.vespa_file, args.es_file,
                                  "phase == 'after_flush' and filter == True",
                                  args.format)
    elif report == 'query_n_refeed':
        print_query_ratio_summary(args.vespa_file, args.es_file,
                                  "phase == 'during_refeed' and filter == False",
                                  args.format)


if __name__ == "__main__":
    main()
