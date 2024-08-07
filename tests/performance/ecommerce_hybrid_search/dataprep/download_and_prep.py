# Copyright Vespa.ai. All rights reserved.

import os
import re
import logging
from pathlib import Path
from typing import Optional, Dict

import numpy as np
import pandas as pd
from datasets import load_dataset
from sentence_transformers import SentenceTransformer

# Constants
MODEL_NAME: str = "Snowflake/snowflake-arctic-embed-xs"
CACHE_PATH: str = "./model_cache"
OUTPUT_DIR: str = "./output-data"

# Setup logger
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

# Ensure the output directory exists
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

categories: list[str] = [
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

# Create a mapping from category to index
category_start_id: Dict[str, int] = {
    cat: i * 10_000_000 for i, cat in enumerate(categories)
}


def load_model() -> SentenceTransformer:
    model = SentenceTransformer(model_name_or_path=MODEL_NAME, cache_folder=CACHE_PATH)
    logging.info(f"Loaded model from {CACHE_PATH}")
    return model


def strip_brackets(text):
    if isinstance(text, str):
        return " ".join(re.findall(r"\[([^][]+)\]", text))
    elif isinstance(text, list):
        return " ".join(strip_brackets(t) for t in text if t)


def clean_data(category: str) -> Optional[pd.DataFrame]:
    logging.info(f"Processing category: {category}")
    # file_path: str = f"{OUTPUT_DIR}/{category}_processed.parquet"
    # if os.path.exists(file_path):
    #     logging.info(f"Already processed {category}")
    #     return None
    prices = np.random.randint(1, 100, 1000)

    ds = load_dataset(
        "McAuley-Lab/Amazon-Reviews-2023", f"raw_meta_{category}", split="full"
    )
    cols_to_keep = ["title", "description", "average_rating", "price"]
    ds = ds.map(
        lambda entry: process_entry(entry, prices),
        batched=False,
        remove_columns=[c for c in ds.column_names if c not in cols_to_keep],
    )
    ds = ds.filter(lambda x: x["description"] is not None)
    df = ds.to_pandas()
    del ds
    df["id"] = df.index + category_start_id[category]
    df["category"] = category
    df.drop_duplicates(subset=["title", "description"], inplace=True)
    # df.loc[df["description"].str.strip() == "", "description"] = None
    df.dropna(subset=["title", "description"], inplace=True)
    df["price"] = (df["price"] * 100).astype(int)
    return df


def process_entry(entry: Dict, prices: np.ndarray) -> Dict:
    price_str = entry["price"]
    try:
        price = float(re.sub(r"[^\d.]", "", price_str))
    except ValueError:
        price = np.random.choice(prices)
    description = strip_brackets(entry["description"]) if entry["description"] else None
    return {
        "title": entry["title"],
        "description": description,
        "average_rating": entry["average_rating"],
        "price": price,
    }


def add_embeddings(df: pd.DataFrame, model: SentenceTransformer) -> pd.DataFrame:
    logging.info("Adding embeddings...")
    documents = "Item: Title: " + df["title"] + " Description: " + df["description"]
    embs = model.encode(documents.tolist(), show_progress_bar=True)
    df["embedding"] = embs.tolist()
    del embs
    logging.info("Embeddings added.")
    return df


def process_category(category: str) -> Optional[pd.DataFrame]:
    model = load_model()
    df = clean_data(category)
    if df is not None:
        df = add_embeddings(df, model)
    return df

if __name__ == "__main__":
    # For creating a subset of the categories:
    # categories = categories[:10]
    for category in categories:
        df_processed = process_category(category)
        if df_processed is None:
            continue
        output_path = os.path.join(OUTPUT_DIR, f"{category}_processed.parquet")
        df_processed.to_parquet(output_path)
        logging.info(f"Data saved to {output_path}")
    # Concatenate all the dataframes and save to a single parquet file
    dfs = []
    for category in categories:
        file_path = os.path.join(OUTPUT_DIR, f"{category}_processed.parquet")
        if os.path.exists(file_path):
            dfs.append(pd.read_parquet(file_path))
    df_all = pd.concat(dfs)
    df_all.reset_index(drop=True, inplace=True)
    num_rows = df_all.shape[0]
    output_path = os.path.join(OUTPUT_DIR, f"ecommerce-{num_rows}.parquet")
    df_all.to_parquet(output_path)
    logging.info(f"Parquet file with {num_rows} rows saved to {output_path}")
