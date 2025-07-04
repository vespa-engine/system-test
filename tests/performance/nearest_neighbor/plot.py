# Copyright Vespa.ai. All rights reserved.

import argparse as ap
import pandas as pd
import matplotlib.pyplot as plt

# Remove filter percentage (-f10- for example) from label
def clean_filter(label):
    splitLabel = label.split("-")
    splitLabel = map(lambda str: str if str[0] != 'f' or (str[0] == 'f' and str[1] == 'f') else "fX", splitLabel)
    splitLabel = filter(None, splitLabel)

    return '-'.join(splitLabel)

def read_filtered_queries(jsonObj):
    response_time = {}

    for row in jsonObj.itertuples():
        row_type = row.parameters["type"]

        if row_type == "query_filter":
            label = clean_filter(row.parameters["label"])
            filter_percent = int(row.parameters["filter_percent"])

            # Only keep filtered results
            if filter_percent == 0:
                continue

            if label not in response_time:
                response_time[label] = {}
            response_time[label][filter_percent] = float(row.metrics["avgresponsetime"])

    return response_time

def read_recall_by_filter(jsonObj):
    recall = {}

    for row in jsonObj.itertuples():
        row_type = row.parameters["type"]

        if row_type == "recall" and "filter_percent" in row.parameters:
            label = clean_filter(row.parameters["label"])
            filter_percent = int(row.parameters["filter_percent"])

            if label not in recall:
                recall[label] = {}
            recall[label][filter_percent] = float(row.metrics["recall.avg"])

    # Ignore single data points
    return {k: v for k, v in recall.items() if len(v) >= 2}

# Remove extended-hits count (-eh10- for example) from label
def clean_extended_hits(label):
    splitLabel = label.split("-")
    splitLabel = map(lambda str: str if str[:2] != 'eh' else "ehX", splitLabel)
    splitLabel = filter(None, splitLabel)

    return '-'.join(splitLabel)

def read_recall_by_extended_hits(jsonObj):
    recall = {}

    for row in jsonObj.itertuples():
        row_type = row.parameters["type"]

        if row_type == "recall":
            label = clean_extended_hits(row.parameters["label"])
            extended_hits = int(row.parameters["explore_hits"])

            if label not in recall:
                recall[label] = {}
            recall[label][extended_hits] = float(row.metrics["recall.avg"])

    # Ignore single data points
    return {k: v for k, v in recall.items() if len(v) >= 2}

# Remove slack (-sl0.1- for example) from label
def clean_slack(label):
    splitLabel = label.split("-")
    splitLabel = map(lambda str: str if str[:2] != 'sl' else "slX", splitLabel)
    splitLabel = filter(None, splitLabel)

    return '-'.join(splitLabel)

def read_recall_by_slack(jsonObj):
    recall = {}

    for row in jsonObj.itertuples():
        row_type = row.parameters["type"]

        if row_type == "recall" and "slack" in row.parameters:
            label = clean_slack(row.parameters["label"])
            slack = float(row.parameters["slack"])

            if label not in recall:
                recall[label] = {}
            recall[label][slack] = float(row.metrics["recall.avg"])

    # Ignore single data points
    return {k: v for k, v in recall.items() if len(v) >= 2}

def read_recall_by_response_time(jsonObj):
    response_time = {}

    # First, we collect the response times
    for row in jsonObj.itertuples():
        row_type = row.parameters["type"]

        if row_type == "query" or row_type == "query_filter":
            # First remove -n1-t0 from end of label
            original_label = row.parameters["label"].rsplit("-", 2)[0]

            response_time[original_label]  = float(row.metrics["avgresponsetime"])

    # Second, we combine this with the recall for extended hits
    recall = {}
    already_seen = set()
    for row in jsonObj.itertuples():
        row_type = row.parameters["type"]

        if row_type == "recall":
            original_label = row.parameters["label"]
            if original_label in already_seen:
                print("Warning: Ambiguous data point for " + original_label)
                continue
            else:
                already_seen.add(original_label)

            if original_label in response_time:
                # Extended hits
                label = clean_extended_hits(original_label)
                if label not in recall:
                    recall[label] = []
                recall[label].append((response_time[original_label], float(row.metrics["recall.avg"])))

                # Slack
                if "slack" in row.parameters:
                    label = clean_slack(original_label)
                    if label not in recall:
                        recall[label] = []
                    recall[label].append((response_time[original_label], float(row.metrics["recall.avg"])))

    # Ignore single data points
    return {k: v for k, v in recall.items() if len(v) >= 2}

def plot_response_time(response_time):
    labels = response_time.keys()
    later = []

    for label in labels:
        # Hack: Draw brute_force results in the end to get colors to match in recall plot
        if "brute_force" in label:
            later.append(label)
            continue
        x = list(response_time[label].keys())
        y = list(response_time[label].values())
        plt.plot(x, y, label=label)

    for label in later:
        x = list(response_time[label].keys())
        y = list(response_time[label].values())
        plt.plot(x, y, label=label)

    plt.xlabel("Fraction filtered out (%)")
    plt.ylabel("Average response time (ms)")
    plt.title("Response Time/Filtered")
    plt.legend()
    axs = plt.gca()
    axs.set_ylim(ymin=0)

def plot_recall_by_filter(recall):
    labels = recall.keys()

    for label in labels:
        x = list(recall[label].keys())
        y = list(recall[label].values())
        plt.plot(x, y, label=label)

    plt.xlabel("Fraction filtered out (%)")
    plt.ylabel("Average recall")
    plt.title("Recall/Filtered")
    plt.legend()

    axs = plt.gca()
    axs.set_ylim(ymin=0)

def plot_recall_by_extended_hits(recall):
    labels = recall.keys()

    for label in labels:
        x = list(recall[label].keys())
        y = list(recall[label].values())
        plt.plot(x, y, "o-", label=label)

    plt.xlabel("Extended hits")
    plt.ylabel("Average recall")
    plt.title("Recall/Extended Hits")
    plt.legend()

    axs = plt.gca()

def plot_recall_by_slack(recall):
    labels = recall.keys()

    for label in labels:
        x = list(recall[label].keys())
        y = list(recall[label].values())
        plt.plot(x, y, "o-", label=label)

    plt.xlabel("Slack")
    plt.ylabel("Average recall")
    plt.title("Recall/Slack")
    plt.legend()

    axs = plt.gca()

def plot_recall_by_response_time(recall):
    labels = recall.keys()

    for label in labels:
        x,y = zip(*recall[label])
        plt.plot(x, y, "o-", label=label)

    plt.xlabel("Response time (ms)")
    plt.ylabel("Average recall")
    plt.title("Recall/Response Time")
    plt.legend()

    axs = plt.gca()
    axs.set_xlim(xmin=0, xmax=10)
    axs.set_ylim(ymin=95, ymax=100)

def plot(filename, save):
    jsonObj = pd.read_json(path_or_buf=filename, lines=True)

    # Response time/filtered
    response_time = read_filtered_queries(jsonObj)
    if response_time:
        plt.figure(1)
        plot_response_time(response_time)
        if save:
            plt.savefig('response_time.png', dpi=300)

    # Recall/filtered
    recall_by_filter = read_recall_by_filter(jsonObj)
    if recall_by_filter:
        plt.figure(2)
        plot_recall_by_filter(recall_by_filter)
        if save:
            plt.savefig('recall_by_filter.png', dpi=300)

    # Recall/extended hits
    recall_by_extended_hits = read_recall_by_extended_hits(jsonObj)
    if recall_by_extended_hits:
        plt.figure(3)
        plot_recall_by_extended_hits(recall_by_extended_hits)
        if save:
            plt.savefig('recall_by_extended_hits.png', dpi=300)

    # Recall/slack
    recall_by_slack = read_recall_by_slack(jsonObj)
    if recall_by_slack:
        plt.figure(4)
        plot_recall_by_slack(recall_by_slack)
        if save:
            plt.savefig('recall_by_slack.png', dpi=300)

    # Recall/response time
    recall_by_response_time = read_recall_by_response_time(jsonObj)
    if recall_by_response_time:
        plt.figure(5)
        plot_recall_by_response_time(recall_by_response_time)
        if save:
            plt.savefig('recall_by_response_time.png', dpi=300)

    plt.show()

def main():
    parser = ap.ArgumentParser(prog='Plot',
                               description='Plot results from ANN performance test')
    parser.add_argument('filename')
    parser.add_argument("--save", help="save plots to file", action="store_true")
    args = parser.parse_args()

    plot(args.filename, args.save)

if __name__=="__main__":
    main()
