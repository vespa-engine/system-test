# Copyright Vespa.ai. All rights reserved.

import argparse
import json
import pandas as pd
import plotly.graph_objects as go
import re
import sys

from pathlib import Path
from plotly.subplots import make_subplots

machine_cpus = 1
test_cpus = 1

def get_cpu(metrics):
    regex = re.compile(r'\["cpuutil", "[^"]+"\]')
    for key, value in metrics.items():
        if regex.match(key):
            return float(value) * machine_cpus
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


def extract_index_segments(file_name):
    res = 9999
    with open(file_name, 'r') as file:
        for line in file.readlines():
            obj = json.loads(line)
            p = obj['parameters']
            m = obj['metrics']
            if not 'query_phase' in p:
                label = p['label']
                if label in ['feed', 'merge']:
                    res = min(res, int(m['segments']))
    return res


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
    if query_filter:
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
        e.to_csv(sys.stdout, index=False, header=False, float_format='%.3f')
        r.to_csv(sys.stdout, index=False, header=False, float_format='%.3f')
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


def load_all_feed_results(vespa_file, es_file):
    v = load_feed_results(vespa_file, "Vespa")
    e = load_feed_results(es_file, "Elasticsearch")
    return pd.concat([v, e])


def load_all_query_results(vespa_file, es_files):
    df = load_query_results(vespa_file, "Vespa", "")
    for es_file in es_files:
        e = load_query_results(es_file, 'es', "")
        segments = extract_index_segments(es_file)
        es_name = 'Elasticsearch (force-merged)' if (segments == 1) else 'Elasticsearch'
        e.replace('es', es_name, inplace=True)
        df = pd.concat([df, e])
    df.replace('weak_and_filter', 'lexical', inplace=True)
    df.replace('semantic_filter', 'vector', inplace=True)
    df.replace('hybrid_filter', 'hybrid', inplace=True)
    df.replace('weak_and', 'lexical', inplace=True)
    df.replace('semantic', 'vector', inplace=True)
    return df


def get_system_color(system):
    # Vespa colors: https://brand.vespa.ai/color
    # Elasticsearch colors: https://loading.io/color/feature/ElasticSearch/
    if system == 'Vespa':
        return '#61d790' # green
    elif system == 'Elasticsearch (force-merged)':
        return '#d7689d'  # pink
    return '#5da4dc' # blue


def add_bar_chart_to_figure(fig, row, col, df, x_col, y_col):
    for system in df['system'].unique():
        filtered_df = df[df['system'] == system]
        fig.add_trace(
            go.Bar(
                name=system,
                x=filtered_df[x_col],
                y=filtered_df[y_col],
                marker_color=get_system_color(system),
                showlegend=(row == 1 and col == 1),
            ),
            row=row, col=col
        )


def add_scatter_plot_to_figure(fig, row, col, df, x_col, y_col):
    for system in df['system'].unique():
        filtered_df = df[df['system'] == system]
        fig.add_trace(
            go.Scatter(
                name=system,
                x=filtered_df[x_col],
                y=filtered_df[y_col],
                mode='lines+markers',
                line_shape='spline',
                marker_color=get_system_color(system),
                showlegend=(row == 1 and col == 1)
            ),
            row=row, col=col
        )


def generate_feed_summary_figure(vespa_file, es_file, output):
    df = load_all_feed_results(vespa_file, es_file)
    file_name = f'{output}/feed_perf.png'
    print(f'\nGenerate feed summary figure: {file_name}')
    print(df)
    fig = make_subplots(rows=2, cols=1)
    add_bar_chart_to_figure(fig, 1, 1, df, 'label', 'throughput')
    add_bar_chart_to_figure(fig, 2, 1, df, 'label', 'throughput_per_cpu')
    fig.update_yaxes(title_text="Throughput (ops/sec)", row=1, col=1)
    fig.update_yaxes(title_text="Throughput per CPU Core", row=2, col=1)
    fig.update_yaxes(nticks=10)
    fig.update_layout(
        title="Write throughput performance",
        height=600,
        legend=dict( # Locate legends above the subplots
            x=0,
            y=1.1,
            orientation='h'
        )
    )
    fig.write_image(file_name, format='png', scale=1.5)


def generate_query_summary_figure(title, file_name, df):
    print(f'\nGenerate query summary figure: {file_name}:')
    print(df)
    fig = make_subplots(
        rows=2,
        cols=2,
        vertical_spacing=0.2,
        subplot_titles=(
            "Average Latency (ms)", "99p Latency (ms)",
            "Queries per Second (QPS)", "QPS per CPU Core"
        )
    )
    add_bar_chart_to_figure(fig, 1, 1, df, 'type', 'l_avg')
    add_bar_chart_to_figure(fig, 1, 2, df, 'type', 'l_99p')
    add_bar_chart_to_figure(fig, 2, 1, df, 'type', 'qps')
    add_bar_chart_to_figure(fig, 2, 2, df, 'type', 'qps_per_cpu')
    fig.update_yaxes(nticks=8)
    fig.update_annotations(font_size=12) # Reduce the font size of subplot titles
    fig.update_layout(
        title=title,
        margin=dict(t=115), # Increase margin space to first subplot row
        legend=dict( # Locate legends above the subplots
            x=0,
            y=1.16,
            orientation='h'
        )
    )
    fig.write_image(file_name, format='png', scale=1.5)


def generate_query_hockey_stick_figure(title, file_name, df):
    print(f'\nGenerate query hockey stick figure: {file_name}:')
    print(df)
    fig = make_subplots(rows=3, cols=1, vertical_spacing=0.08)
    add_scatter_plot_to_figure(fig, 1, 1, df, 'qps', 'l_avg')
    add_scatter_plot_to_figure(fig, 2, 1, df, 'qps', 'l_99p')
    add_scatter_plot_to_figure(fig, 3, 1, df, 'qps', 'cpu_usage')
    fig.update_xaxes(title_text="Queries per Second (QPS)", row=3, col=1)
    fig.update_xaxes(nticks=12)
    fig.update_yaxes(title_text="Average Latency (ms)", row=1, col=1)
    fig.update_yaxes(title_text="99p Latency (ms)", row=2, col=1)
    fig.update_yaxes(nticks=10)
    fig.update_yaxes(title_text="CPU Usage", row=3, col=1)
    fig.update_yaxes(tickvals=[0, 20, 40, 60, 80, 100],
                     ticktext=['0%', '20%', '40%', '60%', '80%', '100%'], row=3, col=1)
    fig.update_layout(
        title=title,
        height=800,
        legend=dict( # Locate legends above the subplots
            x=0,
            y=1.05,
            orientation='h'
        )
    )
    fig.write_image(file_name, format='png', scale=1.5)


def generate_overall_qps_figure(output, df):
    file_name = f'{output}/overall_qps.png'
    print(f'\nGenerate overall qps figure: {file_name}:')
    filtered_df = df.query("phase == 'after_flush' and type == 'hybrid' and filter == True and system != 'Elasticsearch (force-merged)'")
    print(filtered_df)
    fig = make_subplots(rows=2, cols=1, vertical_spacing=0.08)
    add_scatter_plot_to_figure(fig, 1, 1, filtered_df, 'qps', 'l_avg')
    add_scatter_plot_to_figure(fig, 2, 1, filtered_df, 'qps', 'cpu_usage')
    fig.update_xaxes(title_text="Queries per Second (QPS)", row=2, col=1)
    fig.update_xaxes(nticks=12)
    fig.update_yaxes(title_text="Average Latency (ms)", row=1, col=1)
    fig.update_yaxes(nticks=10)
    fig.update_yaxes(title_text="CPU Usage", row=2, col=1)
    fig.update_yaxes(tickvals=[0, 20, 40, 60, 80, 100],
                     ticktext=['0%', '20%', '40%', '60%', '80%', '100%'], row=2, col=1)
    fig.update_layout(
        height=500, # Adjust the height (-100) to compensate for the margin adjustments
        margin=dict(t=50, b=50), # Reduce top and bottom margins as we don't have a title
        legend=dict( # Locate legends above the subplots
            x=0,
            y=1.1,
            orientation='h'
        )
    )
    fig.write_image(file_name, format='png', scale=1.5)


def generate_query_figures(vespa_file, es_files, output):
    df = load_all_query_results(vespa_file, es_files)
    for clients in [1, 16]:
        clients_text = f'({clients} client' + (')' if clients == 1 else 's)')
        file_prefix = f'{output}/query_perf'
        generate_query_summary_figure(f'Query performance after initial feeding {clients_text}',
                                      f'{file_prefix}_after_feed_{clients}_clients.png',
                                      df.query(f"phase == 'after_flush' and filter == False and clients == {clients}"))
        generate_query_summary_figure(f'Filter query performance after initial feeding {clients_text}',
                                      f'{file_prefix}_filter_after_feed_{clients}_clients.png',
                                      df.query(f"phase == 'after_flush' and filter == True and clients == {clients}"))
        generate_query_summary_figure(f'Query performance during re-feeding {clients_text}',
                                      f'{file_prefix}_during_feed_{clients}_clients.png',
                                      df.query(f"phase == 'during_refeed' and filter == True and clients == {clients}"))

    # Convert CPU core to CPU percentage usage
    df['cpu_usage'] = (df['cpu'] / test_cpus) * 100
    for type in df['type'].unique():
        for filter_query in [False, True]:
            filtered_df = df.query(f"phase == 'after_flush' and filter == {filter_query} and type == '{type}'")
            type_text = type + (' filtered' if filter_query else '')
            file_suffix = ('filter_' if filter_query else '') + type
            generate_query_hockey_stick_figure(f'QPS for {type_text} queries after initial feeding',
                                               f'{output}/query_hockey_stick_{file_suffix}.png',
                                               filtered_df)

    generate_overall_qps_figure(output, df)


def generate_overall_summary_figure(vespa_file, es_files, output):
    file_name = f'{output}/overall_perf.png'
    print(f'\nGenerate overall summary figure: {file_name}')
    feed_df = load_all_feed_results(vespa_file, es_files[0])
    query_df = load_all_query_results(vespa_file, es_files)
    filtered_feed_df = feed_df.query("label != 'refeed_with_queries'")
    filtered_query_df = query_df.query("phase == 'after_flush' and filter == True and clients == 16 and system != 'Elasticsearch (force-merged)'")
    print(filtered_feed_df)
    print(filtered_query_df)
    fig = make_subplots(rows=1, cols=2)
    add_bar_chart_to_figure(fig, 1, 1, filtered_query_df, 'type', 'qps_per_cpu')
    add_bar_chart_to_figure(fig, 1, 2, filtered_feed_df, 'label', 'throughput_per_cpu')
    fig.update_yaxes(title_text="QPS per CPU Core", row=1, col=1)
    fig.update_yaxes(title_text="Throughput per CPU Core", row=1, col=2, side='right')
    fig.update_layout(
        height=350, # Adjust the height (-100) to compensate for the margin adjustments
        margin=dict(t=50, b=50), # Reduce top and bottom margins as we don't have a title
        legend=dict( # Locate legends above the subplots
            x=0,
            y=1.15,
            orientation='h'
        ),
        annotations=[ # Add text under each subplot
            dict(
                text="Queries",
                x=0.18, y=-0.15,
                showarrow=False, xref="paper", yref="paper"
            ),
            dict(
                text="Writes",
                x=0.81, y=-0.15,
                showarrow=False, xref="paper", yref="paper"
            )
        ]
    )
    fig.write_image(file_name, format='png', scale=1.5)


def main():
    parser = argparse.ArgumentParser(description="Tool that summarizes feed and query results "
                                                 "between Vespa and ES runs of the performance test")
    # How to use:
    # The results of a performance test run are logged as JSON in the test log output under:
    # '#### Performance results ####'
    # Create a file with these results, one JSON object (per line) per data sample.
    parser.add_argument('vespa_file', type=str, help='Path to Vespa result file')
    parser.add_argument('es_files', nargs='+', help='Path to ES result file(s)')
    parser.add_argument('report_type',
                        choices=['figure', 'feed', 'query', 'query_filter', 'query_refeed'],
                        help='Type of report to create')
    parser.add_argument('--format', default='df', choices=['csv', 'df'], help='Output format printed to stdout')
    parser.add_argument('--machine_cpus', default=128, help='The total number of CPUs on the machine running the performance test. Used when scaling cpuutil metrics into CPU core.')
    parser.add_argument('--test_cpus', default=62, help='The number of CPUs allocated for the performance test')
    parser.add_argument('--output', default='output', help='The folder in which to save generated files')

    args = parser.parse_args()
    report = args.report_type
    global machine_cpus
    global test_cpus
    machine_cpus = int(args.machine_cpus)
    test_cpus = int(args.test_cpus)

    if report == 'figure':
        # Create output folder if it doesn't exist
        Path(args.output).mkdir(parents=True, exist_ok=True)
        generate_feed_summary_figure(args.vespa_file, args.es_files[0], args.output)
        generate_query_figures(args.vespa_file, args.es_files, args.output)
        generate_overall_summary_figure(args.vespa_file, args.es_files, args.output)
    elif report == 'feed':
        print_feed_ratio_summary(args.vespa_file, args.es_files[0], args.format)
    elif report == 'query':
        print_query_ratio_summary(args.vespa_file, args.es_files[0],
                                  "phase == 'after_flush' and filter == False",
                                  args.format)
    elif report == 'query_filter':
        print_query_ratio_summary(args.vespa_file, args.es_files[0],
                                  "phase == 'after_flush' and filter == True",
                                  args.format)
    elif report == 'query_refeed':
        print_query_ratio_summary(args.vespa_file, args.es_files[0],
                                  "phase == 'during_refeed' and filter == True",
                                  args.format)


if __name__ == "__main__":
    main()
