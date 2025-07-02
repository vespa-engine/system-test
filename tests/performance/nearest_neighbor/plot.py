# Copyright Vespa.ai. All rights reserved.

import argparse as ap
import pandas as pd
import matplotlib.pyplot as plt

# Remove filter percentage (-f10- for example) from label
def cleanFilter(label):
    splitLabel = label.split("-")
    splitLabel = map(lambda str: str if str[0] != 'f' else "", splitLabel)
    splitLabel = filter(None, splitLabel)

    return '-'.join(splitLabel)

def read_filtered_queries(jsonObj):
    response_time = {}

    for row in jsonObj.itertuples():
        row_type = row.parameters["type"]

        if row_type == "query_filter":
            label = cleanFilter(row.parameters["label"])
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
            label = cleanFilter(row.parameters["label"])
            filter_percent = int(row.parameters["filter_percent"])

            # Only keep filtered results
            if filter_percent == 0:
                continue

            if label not in recall:
                recall[label] = {}
            recall[label][filter_percent] = float(row.metrics["recall.avg"])

    return recall

def plotResponseTime(response_time):
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

def plotRecall(recall):
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

def plot(filename, save):
    jsonObj = pd.read_json(path_or_buf=filename, lines=True)

    # Response time/filtered
    response_time = read_filtered_queries(jsonObj)
    if response_time:
        plt.figure(1)
        plotResponseTime(response_time)
        if save:
            plt.savefig('response_time.png', dpi=300)

    # Recall/filtered
    recall = read_recall_by_filter(jsonObj)
    if recall:
        plt.figure(2)
        plotRecall(recall)
        if save:
            plt.savefig('recall.png', dpi=300)

    plt.show()

def main():
    parser = ap.ArgumentParser(prog='Plot',
                               description='Plot results from ANN performance test')
    parser.add_argument('--file', nargs='?', const="result.jsonl", type=str, default="result.jsonl")
    parser.add_argument("--save", help="save plots to file", action="store_true")
    args = parser.parse_args()

    plot(args.file, args.save)

if __name__=="__main__":
    main()
