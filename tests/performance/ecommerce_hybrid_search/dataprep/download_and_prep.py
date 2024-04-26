import os
import re
import numpy as np
import pandas as pd
from datasets import load_dataset
from sentence_transformers import SentenceTransformer
from multiprocessing import Pool
from typing import Any, Dict, List, Union
import subprocess
from dataclasses import dataclass
import logging
import argparse

logging.basicConfig(format="%(asctime)s - %(message)s", level=logging.INFO)

# Global configurations
CACHE_PATH = "./model_cache"
MODEL_NAME = "Snowflake/snowflake-arctic-embed-xs"
OUTPUT_DIR = "./output-data"

VESPA_DOCTYPE = "product"
VESPA_NAMESPACE = "product"

# Ensure output directory exists
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)


# Dataclass to store processing results
@dataclass
class ProcessingResult:
    cat: str
    length: int
    cleaned: bool = False
    embeddings_added: bool = False
    vespa_format_saved: bool = False
    merged: bool = False

    # Add str method suited for logging
    def __str__(self) -> str:
        return (
            f"Category: {self.cat}, Length: {self.length}, "
            f"Cleaned: {self.cleaned}, Embeddings Added: {self.embeddings_added}, "
            f"Vespa Format Saved: {self.vespa_format_saved}"
        )


def download_model_weights() -> None:
    model = SentenceTransformer(model_name_or_path=MODEL_NAME, cache_folder=CACHE_PATH)
    print(f"Model {model} downloaded to {CACHE_PATH}")
    # Print device - want to make sure it's using mps
    print(f"Device: {model.device}")
    # Save model to cache
    model.save(f"{CACHE_PATH}/{MODEL_NAME}")


def strip_brackets(text: Union[str, List[str]]) -> Union[str, None]:
    """
    Strips content within brackets from a string.
    Used for cleaning the description column.

    If the input is a list, it joins the elements.
    Examples:
    - strip_brackets("This is a [text]") -> "text"
    - strip_brackets(["This is a [text]", "Another [text]"]) -> "text text"

    """
    if isinstance(text, str):
        pattern = r"\[([^][]+)\]"
        res = re.findall(pattern, text)
        return " ".join(res) if res else text
    elif isinstance(text, list):
        return "".join(text) if len(text) > 0 else None


def clean_data(cat: str, overwrite: bool = False) -> ProcessingResult:
    file_path = f"{OUTPUT_DIR}/{cat}.json.gz"
    if os.path.exists(file_path) and not overwrite:
        df = pd.read_json(file_path, compression="gzip")
        return ProcessingResult(cat=cat, length=len(df))

    # prices should be a numpy array of 1000 integers between 0 and 1000
    prices = np.random.randint(1, 1000, 1000)

    def process_entry(entry: Dict[str, Any]) -> Dict[str, Union[str, float, None]]:
        price_str = entry["price"]
        try:
            price = float(re.sub(r"[^\d.]", "", price_str))
        except ValueError:
            price = np.random.choice(prices)

        description = (
            strip_brackets(entry["description"]) if entry["description"] else None
        )
        return {
            "title": entry["title"],
            "description": description,
            "average_rating": entry["average_rating"],
            "price": price,
        }

    ds = load_dataset(
        "McAuley-Lab/Amazon-Reviews-2023", f"raw_meta_{cat}", split="full"
    )
    ds = ds.map(process_entry, batched=False)
    ds = ds.filter(lambda x: x["description"] is not None)
    # Remove columns not needed
    use_cols = ["title", "description", "average_rating", "price"]
    ds = ds.remove_columns([col for col in ds.column_names if col not in use_cols])
    df = ds.to_pandas()
    df["price"] = df["price"].astype(int)
    # Use incrementing id per category for new. Must remember to make unique when merging.
    df["id"] = range(1, len(df) + 1)
    if len(df) > 0:
        df.to_json(file_path, compression="gzip")
    return ProcessingResult(cat=cat, length=len(df), cleaned=True)


def add_embeddings(
    cat: str, embeddings_path=str, raw_path=str, overwrite: bool = False
) -> Union[pd.DataFrame, None]:
    if os.path.exists(embeddings_path) and not overwrite:
        return pd.read_json(embeddings_path, compression="gzip")
    try:
        df = pd.read_json(raw_path, compression="gzip")
    except FileNotFoundError:
        print(f"File {cat}.json.gz not found")
        return None
    # initialize model from cache
    model = SentenceTransformer(model_name_or_path=MODEL_NAME, cache_folder=CACHE_PATH)
    documents = "Item: Title: " + df["title"] + " Description: " + df["description"]
    document_embeddings = model.encode(documents.tolist())
    df["embedding"] = document_embeddings.tolist()
    return df


def merge_files(categories: List[str]) -> ProcessingResult:
    merged_path = f"{OUTPUT_DIR}/merged.json.gz"
    if os.path.exists(merged_path):
        return

    dfs = []
    for cat in categories:
        try:
            df = pd.read_json(
                f"{OUTPUT_DIR}/{cat}_embeddings.json.gz", compression="gzip"
            )
            dfs.append(df)
        except FileNotFoundError:
            print(f"File {cat}_embeddings.json.gz not found")

    if dfs:
        merged = pd.concat(dfs, ignore_index=True)
        # Make sure id is unique
        merged["id"] = range(1, len(merged) + 1)
        merged.to_json(merged_path, compression="gzip")
        return ProcessingResult(cat="all", length=len(merged), merged=True)


def save_df_to_vespa_format(
    df: pd.DataFrame, cat: str, file_name: str, temp_result: ProcessingResult
) -> ProcessingResult:
    """
    Transform the DataFrame to a Vespa-compatible format.
    Save transformed data to a newline-separated JSON file.
    """
    df["docid"] = f"id:{VESPA_DOCTYPE}:{VESPA_NAMESPACE}::" + df["id"].astype(str)
    df.rename(columns={"embeddings": "embedding"}, inplace=True)
    df = df.apply(
        lambda row: {
            "put": row["docid"],
            "fields": {
                "id": row["id"],
                "title": row["title"],
                "description": row["description"],
                "price": row["price"],
                "average_rating": row["average_rating"],
                "embedding": row["embedding"],
            },
        },
        axis=1,
    )
    df.to_json(file_name, orient="records", lines=True, compression="gzip")
    temp_result.vespa_format_saved = True
    return temp_result


def subprocess_download(file_name: str) -> bool:
    """
    Download a file with modal CLI using subprocess.
    Print output to stdout.
    """
    cmd = f"modal volume get output-data {file_name}"
    try:
        out = subprocess.run(cmd, shell=True, check=True)
        print(out.stdout)
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False


def process_category(
    cat: str,
    overwrite: bool = False,
) -> ProcessingResult:
    RAW_PATH = f"{OUTPUT_DIR}/{cat}.json.gz"
    EMBEDDING_PATH = f"{OUTPUT_DIR}/{cat}_embeddings.json.gz"
    VESPA_PATH = f"{OUTPUT_DIR}/{cat}_vespa.json.gz"
    ES_PATH = f"{OUTPUT_DIR}/{cat}_es.json.gz"
    # Download and clean data
    clean_result: ProcessingResult = clean_data(cat, overwrite=overwrite)
    logging.info(f"{clean_result}")
    if clean_result.length == 0:
        return clean_result
    # Add embeddings
    df_emb: pd.DataFrame = add_embeddings(
        cat=cat, embeddings_path=EMBEDDING_PATH, raw_path=RAW_PATH, overwrite=overwrite
    )
    if overwrite or not os.path.exists(EMBEDDING_PATH):
        df_emb.to_json(EMBEDDING_PATH, compression="gzip")
    result = ProcessingResult(
        cat=cat, length=len(df_emb), cleaned=True, embeddings_added=True
    )
    logging.info(f"{result}")
    # Save to Vespa format
    if overwrite or not os.path.exists(VESPA_PATH):
        result: ProcessingResult = save_df_to_vespa_format(
            df=df_emb,
            cat=cat,
            file_name=VESPA_PATH,
            temp_result=result,
        )
    logging.info(f"{result}")
    # TODO: Save to es-format
    return result


def main_parallel(categories: List[str], num_processes: int) -> List[ProcessingResult]:
    with Pool(processes=num_processes) as pool:
        results = pool.map(process_category, categories)
    return results


def parse_args():
    parser = argparse.ArgumentParser(description="Process some integers.")
    parser.add_argument(
        "--overwrite",
        type=bool,
        default=False,
        help="a flag to overwrite existing files",
    )
    parser.add_argument(
        "--num_processes", type=int, default=4, help="number of processes to use"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    download_model_weights()  # Download model weights once at the beginning
    categories = [
        "All_Beauty",
        "Amazon_Fashion",
        "Appliances",
        "Arts_Crafts_and_Sewing",
        "Automotive",
        "Baby_Products",
        "Beauty_and_Personal_Care",
        "Books",
        "CDs_and_Vinyl",
        "Cell_Phones_and_Accessories",
        "Clothing_Shoes_and_Jewelry",
        "Digital_Music",
        "Electronics",
        "Gift_Cards",
        "Grocery_and_Gourmet_Food",
        "Handmade_Products",
        "Health_and_Household",
        "Health_and_Personal_Care",
        "Home_and_Kitchen",
        "Industrial_and_Scientific",
        "Kindle_Store",
        "Magazine_Subscriptions",
        "Movies_and_TV",
        "Musical_Instruments",
        "Office_Products",
        "Patio_Lawn_and_Garden",
        "Pet_Supplies",
        "Software",
        "Sports_and_Outdoors",
        "Subscription_Boxes",
        "Tools_and_Home_Improvement",
        "Toys_and_Games",
        "Video_Games",
        "Unknown",
    ]
    overwrite = args.overwrite
    results = main_parallel(categories, num_processes=args.num_processes)
    print(results)
    # Will merge later. Not properly tested yet.
    # merge_files(categories, overwrite=args.overwrite)
