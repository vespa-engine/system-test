# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.


import os
import json
import argparse
import logging
from typing import Dict, List
import seaborn as sns
import matplotlib.pyplot as plt


def clean_results(result_file_path: str) -> Dict[int, List[Dict[str, int]]]:
    """
    Clean the results from a file and return a dictionary of results.

    :param result_file_path: Path to the result file.
    :return: A dictionary of results.
    """
    if not os.path.exists(result_file_path):
        raise FileNotFoundError(f"File {result_file_path} does not exist.")

    logging.info(f"Cleaning results from {result_file_path}")
    vespa_in_file = "vespa" in result_file_path
    es_in_file = "es" in result_file_path
    if vespa_in_file:
        application = "vespa"
    elif es_in_file:
        application = "es"
    else:
        raise ValueError("File must be either vespa or es")
    all_results = {}
    query_id_counter = 1
    with open(result_file_path, "r") as file:
        lines = file.readlines()
        for line in lines:
            if line.startswith("{"):
                result_dict = json.loads(line)
                if application == "es":
                    hits = result_dict["hits"]["hits"]
                    individual_results = [
                        {"id": int(hit["_id"]), "relevance": hit["_score"]}
                        for hit in hits
                    ]
                elif application == "vespa":
                    root = result_dict["root"]
                    children = root["children"] if ("children" in root) else []
                    individual_results = [
                        {"id": child["fields"]["id"], "relevance": child["relevance"]}
                        for child in children
                    ]
                assert len(individual_results) <= 10, individual_results
                all_results[query_id_counter] = individual_results
                query_id_counter += 1
    return all_results


def calculate_overlaps(
    vespa_fbench_output_path: str, es_fbench_output_path: str
) -> Dict[int, float]:
    """
    Calculate the overlaps between Vespa and Elasticsearch results.

    :param vespa_fbench_output_path: Path to the Vespa fbench output file.
    :param es_fbench_output_path: Path to the Elasticsearch fbench output file.
    :return: A dictionary of overlaps.
    """
    if not os.path.exists(vespa_fbench_output_path) or not os.path.exists(
        es_fbench_output_path
    ):
        raise FileNotFoundError("One or both of the provided file paths do not exist.")

    vespa_results: dict = clean_results(vespa_fbench_output_path)
    logging.info(f"Vespa results cleaned - length: {len(vespa_results)}")
    es_results: dict = clean_results(es_fbench_output_path)
    logging.info(f"Elasticsearch results cleaned - length: {len(es_results)}")
    min_queries = min(len(vespa_results), len(es_results))
    overlap = {}
    for query_id in range(1, min_queries + 1):
        vespa_top_10 = {result["id"] for result in vespa_results[query_id]}
        es_top_10 = {result["id"] for result in es_results[query_id]}
        overlap[query_id] = len(vespa_top_10.intersection(es_top_10)) / 10
    return overlap


def plot_overlap(overlap: Dict[int, float], output_path: str, query_mode: str):
    """
    Plot a histogram of the overlap.

    :param overlap: A dictionary of overlaps.
    """
    bins = [x / 10 for x in range(11)]
    avg_overlap = sum(overlap.values()) / len(overlap)
    sns.histplot(overlap.values(), bins=bins)
    plt.title(f"Overlap in the top 10 results for {query_mode}")
    plt.legend([f"Evaluated queries: {len(overlap)}"])
    plt.text(
        0.5,
        0.5,
        f"Average overlap: {avg_overlap:.2f}",
        horizontalalignment="center",
        verticalalignment="center",
        transform=plt.gca().transAxes,
    )
    # Log average overlap
    logging.info(f"Average overlap for {query_mode}: {avg_overlap:.2f}")
    plt.savefig(os.path.join(output_path, "overlap_histogram_" + query_mode + ".png"))
    # Clear the plot for the next iteration
    plt.clf()


def check_if_path_exists(path: str) -> bool:
    if not os.path.exists(path):
        raise FileNotFoundError(f"File {path} does not exist.")
    return True


def main():
    parser = argparse.ArgumentParser(description="Analyze overlap.")
    parser.add_argument(
        "--querymodes",
        nargs="*",
        default=["weak_and", "weak_and_filter", "semantic", "semantic_filter", "hybrid", "hybrid_filter"],
        help="Query modes to analyze. Set to empty list to analyze only provided files.",
    )
    parser.add_argument(
        "--vespa_fbench_output_path",
        default="../dataprep/output-data/final/fbench_output_vespa.txt",
    )
    parser.add_argument(
        "--es_fbench_output_path",
        default="../dataprep/output-data/final/fbench_output_es.txt",
    )
    parser.add_argument("--output_path", default=".")
    args = parser.parse_args()

    if not os.path.exists(args.output_path):
        os.makedirs(args.output_path)

    logging.basicConfig(level=logging.INFO)
    if len(args.querymodes) == 0:
        vespa_fbench_output_path = args.vespa_fbench_output_path
        es_fbench_output_path = args.es_fbench_output_path
        overlap = calculate_overlaps(vespa_fbench_output_path, es_fbench_output_path)
        plot_overlap(overlap, args.output_path, "")
    else:
        for query_mode in args.querymodes:
            vespa_fbench_output_path = args.vespa_fbench_output_path.replace(
                ".txt", f"_{query_mode}.txt"
            )
            # Log inferred paths
            if check_if_path_exists(vespa_fbench_output_path):
                logging.info(
                    f"Inferred vespa fbench output path: {vespa_fbench_output_path}"
                )
            es_fbench_output_path = args.es_fbench_output_path.replace(
                ".txt", f"_{query_mode}.txt"
            )
            if check_if_path_exists(es_fbench_output_path):
                logging.info(f"Inferred es fbench output path: {es_fbench_output_path}")
            overlap = calculate_overlaps(
                vespa_fbench_output_path, es_fbench_output_path
            )
            plot_overlap(overlap, args.output_path, query_mode)


if __name__ == "__main__":
    main()
