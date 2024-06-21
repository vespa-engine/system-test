# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import json
import logging
import argparse
from pathlib import Path
from enum import Enum
import re
import tqdm

import pandas as pd
import zstandard as zstd  # For compression
import os
import datetime

# Setup basic configuration for logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

# Constants
OUTPUT_DIR = "./output-data/"

# Create a new directory for the final output, named with timestamp
FINAL_DIR = OUTPUT_DIR + datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + "/"
os.makedirs(FINAL_DIR)

# Vespa and Elasticsearch constants
VESPA_DOCTYPE = "product"
VESPA_NAMESPACE = "product"
ES_INDEX = "product"

# Ensure the output directory exists
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)


class QueryTypeEnum(Enum):
    WEAK_AND = "weak_and"
    SEMANTIC = "semantic"
    HYBRID = "hybrid"

    def __str__(self):
        return self.value


def human_readable_number(num):
    """Convert numbers to human-readable format for filenames, ensuring integer values below 1000 do not have unnecessary decimals."""
    for unit in ["", "k", "M", "B"]:
        if abs(num) < 1000:
            if num == int(num):
                return f"{int(num)}{unit}"  # No decimal for whole numbers
            return f"{num:.1f}".rstrip(".0") + unit
        num /= 1000
    return f"{num:.1f}T"


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Process some integers.")
    parser.add_argument(
        "num_samples", type=int, help="Number of samples to process (positive integer)"
    )
    args = parser.parse_args()

    if args.num_samples <= 0:
        raise ValueError("Number of samples must be a positive integer.")

    return args.num_samples

def load_parquet_file(basefile_path: str) -> pd.DataFrame:
    try:
        df = pd.read_parquet(basefile_path)
        logging.info(f"Loaded {basefile_path} with {len(df)} records")
        return df
    except FileNotFoundError:
        logging.error(f"File {basefile_path} not found")
        return pd.DataFrame()

def clean_and_prepare_df(df: pd.DataFrame) -> pd.DataFrame:
    df = df.drop_duplicates(subset=["title", "description"])
    # Reset index to integer values
    df.reset_index(drop=True, inplace=True)
    # Set index to id column (use .loc to avoid SettingWithCopyWarning)
    df.loc[:, "id"] = df.index
    # assert (
    #     df["description"].str.strip().eq("").sum() == 0
    # ), "Empty strings in descriptions"
    assert df["id"].duplicated().sum() == 0, "Duplicated IDs found"
    assert df.isnull().sum().sum() == 0, "NaN values found in DataFrame"
    return df


def save_vespa_feed_file(df: pd.DataFrame, file_name: Path) -> None:
    file_name = file_name.with_suffix(".json.zst")
    cctx = zstd.ZstdCompressor(level=1)
    with open(file_name, "wb") as f:
        with cctx.stream_writer(f) as compressor:
            for index, row in tqdm.tqdm(df.iterrows(), total=len(df)):
                row_dict = {
                    "put": f"id:{VESPA_DOCTYPE}:{VESPA_NAMESPACE}::{row['category']}{row['id']}",
                    "fields": {
                                "id": row["id"],
                                "title": row["title"],
                                "category": row["category"],
                                "description": row["description"],
                                "price": row["price"],
                                "average_rating": row["average_rating"],
                                "embedding": row["embedding"].tolist(),
                            }
                    }
                row_json = json.dumps(row_dict, ensure_ascii=True) + "\n"
                compressor.write(row_json.encode("utf-8"))
    
    logging.info(f"Vespa feed file saved to {file_name}")


def save_vespa_update_file(df: pd.DataFrame, file_name: Path) -> None:
    file_name = file_name.with_suffix(".json.zst")
    cctx = zstd.ZstdCompressor(level=1)
    with open(file_name, "wb") as f:
        with cctx.stream_writer(f) as compressor:
            for index, row in tqdm.tqdm(df.iterrows(), total=len(df)):
                row_dict = {
                    "update": f"id:{VESPA_DOCTYPE}:{VESPA_NAMESPACE}::{row['category']}{row['id']}",
                    "fields": {
                        "price": {
                            "assign": row["price"] + 100
                        }
                    }
                }
                row_json = json.dumps(row_dict, ensure_ascii=True) + "\n"
                compressor.write(row_json.encode("utf-8"))

    logging.info(f"Vespa update file saved to {file_name}")


def save_es_feed_file(df: pd.DataFrame, file_name: Path) -> None:
    file_name = file_name.with_suffix(".json.zst")
    cctx = zstd.ZstdCompressor(level=1)
    
    with open(file_name, "wb") as f:
        with cctx.stream_writer(f) as compressor:
            for index, row in tqdm.tqdm(df.iterrows(), total=len(df)):
                action = {"index": {"_index": ES_INDEX, "_id": str(row["id"])}}
                action_json = json.dumps(action, ensure_ascii=True) + "\n"
                compressor.write(action_json.encode("utf-8"))
                
                doc_data = {
                    "title": row["title"],
                    "category": row["category"],
                    "description": row["description"],
                    "price": row["price"],
                    "average_rating": row["average_rating"],
                    "embedding": row["embedding"].tolist(),
                }
                doc_json = json.dumps(doc_data, ensure_ascii=True) + "\n"
                compressor.write(doc_json.encode("utf-8"))
    
    logging.info(f"Elasticsearch feed file saved to {file_name}")


def save_es_update_file(df: pd.DataFrame, file_name: Path) -> None:
    file_name = file_name.with_suffix(".json.zst")
    cctx = zstd.ZstdCompressor(level=1)

    with open(file_name, "wb") as f:
        with cctx.stream_writer(f) as compressor:
            for index, row in tqdm.tqdm(df.iterrows(), total=len(df)):
                action = {"update": {"_index": ES_INDEX, "_id": str(row["id"])}}
                action_json = json.dumps(action, ensure_ascii=True) + "\n"
                compressor.write(action_json.encode("utf-8"))
                update_data = {
                    "doc": {
                        "price": row["price"] + 100
                    }
                }
                update_json = json.dumps(update_data, ensure_ascii=True) + "\n"
                compressor.write(update_json.encode("utf-8"))

    logging.info(f"Elasticsearch update file saved to {file_name}")


def title_to_query(title: str) -> str:
    # If the title is more than 8 words, use the first 8 words.
    # If it is less than 8 words, use the whole title.
    return " ".join(title.split()[:8])


def remove_quote_chars(query: str) -> str:
    """Should remove both single and double quotes from the query."""
    # Use regex compiled for performance
    remove_double_quotes = re.compile(r'"')
    remove_single_quotes = re.compile(r"'")
    return remove_double_quotes.sub("", remove_single_quotes.sub("", query))


def write_queries_to_file(queries: list, endpoint: str, query_save_path: Path) -> None:
    # Write alternating lines to data (endpoint, request) as needed by vespa-fbench.
    data = ""
    for query in queries:
        data += endpoint + "\n"
        data += json.dumps(query, ensure_ascii=True) + "\n"
    if len(queries) < 1000:
        with open(query_save_path.with_suffix(""), "w") as f:
            f.write(data)
        return
    else:
        cctx = zstd.ZstdCompressor()
        compressed_data = cctx.compress(data.encode("utf-8"))
        with open(query_save_path, "wb") as f:
            f.write(compressed_data)


def vespa_yql(query_type: QueryTypeEnum, category: str) -> str:
    category_filter = f'category contains "{category}" and ' if category else ""
    if query_type == QueryTypeEnum.WEAK_AND:
        return f'select * from product where {category_filter}userQuery()'
    elif query_type == QueryTypeEnum.SEMANTIC:
        return f'select * from product where {category_filter}({{targetHits:100}}nearestNeighbor(embedding,q_embedding))'
    elif query_type == QueryTypeEnum.HYBRID:
        return f'select * from product where {category_filter}(({{targetHits:100}}nearestNeighbor(embedding,q_embedding)) or userQuery())'


def save_vespa_query_files_from_df(
    df: pd.DataFrame,
    query_save_path: Path,
    num_queries: int,
    query_type: QueryTypeEnum = QueryTypeEnum.WEAK_AND,
    category_filter: bool = True
) -> None:
    """
    Create a query file to benchmark Vespa using vespa-fbench.
    """
    endpoint = "/search/"
    # Validate number of queries requested is less than the total number of samples
    if num_queries > len(df):
        raise ValueError(
            "Number of queries requested is greater than the total number of samples available."
        )
    # Sample the dataframe set random state for reproducibility
    df = df.sample(num_queries, random_state=42)
    base_parameters = {
        "presentation.summary": "minimal",
        "hits": 10,
    }
    # Generate list of queries
    queries = df["title"].apply(title_to_query).tolist()
    categories = df["category"].tolist() if category_filter else [None] * num_queries
    if query_type == QueryTypeEnum.WEAK_AND:
        full_queries = [
            {
                "yql": vespa_yql(query_type, category),
                **base_parameters,
                "ranking.profile": "bm25",
                "query": remove_quote_chars(query)
            }
            for query, category in zip(queries, categories)
        ]
    else:
        embeddings = df["embedding"].tolist()
        if query_type == QueryTypeEnum.SEMANTIC:
            full_queries = [
                {
                    "yql": vespa_yql(query_type, category),
                    **base_parameters,
                    "ranking.profile": "closeness",
                    "input.query(q_embedding)": embedding.tolist(),
                }
                for category, embedding in zip(categories, embeddings)
            ]
        elif query_type == QueryTypeEnum.HYBRID:
            full_queries = [
                {
                    "yql": vespa_yql(query_type, category),
                    **base_parameters,
                    "ranking.profile": "hybrid",
                    "query": remove_quote_chars(query),
                    "input.query(q_embedding)": embedding.tolist(),
                }
                for query, category, embedding in zip(queries, categories, embeddings)
            ]
    write_queries_to_file(full_queries, endpoint, query_save_path)


def es_query(query: str, category: str) -> dict:
    multi_match = {
        "multi_match": {
            "query": remove_quote_chars(query),
            "fields": ["title", "description"],
            "type": "best_fields"
        }
    }
    if category:
        return {
            "bool": {
                "must": multi_match,
                "filter": [{"term": {"category": category}}]
            }
        }
    return multi_match


def es_knn(embedding, category: str) -> dict:
    knn = {
        "field": "embedding",
        "query_vector": embedding.tolist(),
        "num_candidates": 100,
        "k": 10,
    }
    if category:
        return {**knn, "filter": [{"term": {"category": category}}]}
    return knn


def save_es_query_files_from_df(
    df: pd.DataFrame,
    query_save_path: Path,
    num_queries: int,
    query_type: QueryTypeEnum = QueryTypeEnum.WEAK_AND,
    category_filter: bool = False
) -> None:
    """
    Create a query file to benchmark Elasticsearch using vespa-fbench.
    """
    endpoint = "/" + ES_INDEX + "/_search/"
    # Validate number of queries requested is less than the total number of samples
    if num_queries > len(df):
        raise ValueError(
            "Number of queries requested is greater than the total number of samples available."
        )
    # Sample the dataframe set random state for reproducibility
    df = df.sample(num_queries, random_state=42)
    base_parameters = {
        "size": 10,
        "fields": ["id"],
        "_source": False,
    }
    # Generate list of queries
    queries = df["title"].apply(title_to_query).tolist()
    categories = df["category"].tolist() if category_filter else [None] * num_queries
    if query_type == QueryTypeEnum.WEAK_AND:
        full_queries = [
            {
                **base_parameters,
                "query": es_query(query, category)
            }
            for query, category in zip (queries, categories)
        ]
    else:
        embeddings = df["embedding"].tolist()
        if query_type == QueryTypeEnum.SEMANTIC:
            full_queries = [
                {
                    **base_parameters,
                    "knn": es_knn(embedding, category)
                }
                for embedding, category in zip(embeddings, categories)
            ]
        elif query_type == QueryTypeEnum.HYBRID:
            full_queries = [
                {
                    **base_parameters,
                    "query": es_query(query, category),
                    "knn": es_knn(embedding, category)
                }
                for query, category, embedding in zip(queries, categories, embeddings)
            ]
    write_queries_to_file(full_queries, endpoint, query_save_path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--basefile_path",
        type=str,
        default=OUTPUT_DIR + "ecommerce-5M.parquet",
        help="Path to the parquet file to be loaded",
    )
    parser.add_argument(
        "--mode",
        choices=["feed", "update", "query", "all"],
        default="feed",
        help="Mode of operation: generate data feeds or queries.",
    )
    parser.add_argument(
        "--num_samples",
        type=int,
        default=1_000_000,
        help="Number of samples to process (positive integer)",
    )
    parser.add_argument(
        "--num_queries",
        type=int,
        default=10_000,
        help="Number of queries to generate",
    )
    args = parser.parse_args()
    num_samples = args.num_samples
    num_queries = args.num_queries
    basefile_path = args.basefile_path
    logging.info(f"Loading data from {basefile_path}")
    df = load_parquet_file(basefile_path)
    logging.info(f"Loaded {len(df)} records")
    df = clean_and_prepare_df(df)
    logging.info(f"After clean and prepare: {len(df)} records")
    if num_samples > len(df):
        raise ValueError(
            f"Number of samples requested is greater than the total number of samples available: {len(df)}"
        )
    df = df.iloc[:num_samples]
    df = df.sample(num_samples, random_state=42)
    shorthand_samples = human_readable_number(num_samples)
    if args.mode in ["feed", "all"]:
        vespa_save_path = Path(FINAL_DIR) / f"vespa_feed-{shorthand_samples}.jsonl"
        es_save_path = Path(FINAL_DIR) / f"es_feed-{shorthand_samples}.jsonl"
        logging.info(f"Preparing Vespa feed file...")
        save_vespa_feed_file(df, vespa_save_path)
        logging.info(f"Preparing Elasticsearch feed file...")
        save_es_feed_file(df, es_save_path)
    if args.mode in ["update", "all"]:
        vespa_save_path = Path(FINAL_DIR) / f"vespa_update-{shorthand_samples}.jsonl"
        es_save_path = Path(FINAL_DIR) / f"es_update-{shorthand_samples}.jsonl"
        logging.info(f"Preparing Vespa update file...")
        save_vespa_update_file(df, vespa_save_path)
        logging.info(f"Preparing Elasticsearch update file...")
        save_es_update_file(df, es_save_path)
    if args.mode in ["query", "all"]:
        logging.info("Preparing query files...")
        shorthand_queries = human_readable_number(num_queries)
        for query_type in QueryTypeEnum:
            for category_filter in [False, True]:
                filter_str = "-filter" if category_filter else ""
                vespa_save_path = (
                    Path(FINAL_DIR)
                    / f"vespa_queries-{query_type}{filter_str}-{shorthand_queries}.json.zst"
                )
                logging.info(f"Generating {query_type}{filter_str} queries")
                save_vespa_query_files_from_df(df, vespa_save_path, num_queries, query_type, category_filter)
                es_save_path = (
                    Path(FINAL_DIR)
                    / f"es_queries-{query_type}{filter_str}-{shorthand_queries}.json.zst"
                )
                save_es_query_files_from_df(df, es_save_path, num_queries, query_type, category_filter)


if __name__ == "__main__":
    main()
