import json
import logging
import argparse
from pathlib import Path

import pandas as pd
import zstandard as zstd  # For compression

# Setup basic configuration for logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

# Constants
OUTPUT_DIR = "./output-data/"
FINAL_DIR = OUTPUT_DIR + "final/"

# Vespa and Elasticsearch constants
VESPA_DOCTYPE = "product"
VESPA_NAMESPACE = "product"
ES_INDEX = "product"

# Ensure the output directory exists
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)


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


def process_parquet_files(output_dir: str) -> pd.DataFrame:
    parquet_files = list(Path(output_dir).rglob("*.parquet"))
    if not parquet_files:
        logging.info("No parquet files found.")
        return pd.DataFrame()
    df = pd.concat([pd.read_parquet(file) for file in parquet_files], ignore_index=True)
    logging.info(f"Total records loaded: {len(df)}")
    return df


def clean_and_prepare_df(df: pd.DataFrame) -> pd.DataFrame:
    df = df.drop_duplicates(subset=["title", "description"])
    # Set index to id column (use .loc to avoid SettingWithCopyWarning)
    df.loc[:, "id"] = df.index
    # assert (
    #     df["description"].str.strip().eq("").sum() == 0
    # ), "Empty strings in descriptions"
    assert df["id"].duplicated().sum() == 0, "Duplicated IDs found"
    assert df.isnull().sum().sum() == 0, "NaN values found in DataFrame"
    return df


def save_df_to_vespa_format(df: pd.DataFrame, file_name: Path) -> None:
    df = df.apply(
        lambda row: {
            "put": f"id:{VESPA_DOCTYPE}:{VESPA_NAMESPACE}::{row['category']}{row['id']}",
            "fields": {
                "id": row["id"],
                "title": row["title"],
                "category": row["category"],
                "description": row["description"],
                "price": row["price"],
                "average_rating": row["average_rating"],
                "embedding": row["embedding"].tolist(),
            },
        },
        axis=1,
    )
    file_name = file_name.with_suffix(".json.zst")
    df.to_json(file_name, orient="records", lines=True, compression="zstd")
    logging.info(f"Data saved in Vespa format to {file_name}")


def save_df_to_es_format(df: pd.DataFrame, file_name: Path) -> None:
    file_name = file_name.with_suffix(".json.zst")
    data = ""
    for index, row in df.iterrows():
        action = {"index": {"_index": ES_INDEX, "_id": str(row["id"])}}
        data += json.dumps(action) + "\n"
        doc_data = {
            "title": row["title"],
            "category": row["category"],
            "description": row["description"],
            "price": row["price"],
            "average_rating": row["average_rating"],
            "embedding": row["embedding"].tolist(),
        }
        data += json.dumps(doc_data) + "\n"
    cctx = zstd.ZstdCompressor()
    compressed_data = cctx.compress(data.encode("utf-8"))
    with open(file_name, "wb") as f:
        f.write(compressed_data)
    logging.info(f"Data saved in Elasticsearch format to {file_name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "num_samples",
        type=int,
        default=100,
        help="Number of samples to process (positive integer)",
    )
    num_samples = parse_args()
    df = process_parquet_files(OUTPUT_DIR)
    df = clean_and_prepare_df(df)
    if num_samples > len(df):
        raise ValueError(
            "Number of samples requested is greater than the total number of samples available."
        )
    shorthand_samples = human_readable_number(num_samples)
    vespa_save_path = Path(FINAL_DIR) / f"vespa_feed-{shorthand_samples}.jsonl"
    es_save_path = Path(FINAL_DIR) / f"es_feed-{shorthand_samples}.jsonl"
    df = df.sample(num_samples, random_state=42)
    save_df_to_vespa_format(df, vespa_save_path)
    save_df_to_es_format(df, es_save_path)


if __name__ == "__main__":
    main()
