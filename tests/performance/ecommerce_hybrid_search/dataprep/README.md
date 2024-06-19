# Dataprep

This folder contains the scripts to prepare the data for the hybrid search benchmark.
The data is based on this dataset: https://huggingface.co/datasets/McAuley-Lab/Amazon-Reviews-2023.

The dataset preparation is done in two steps:

1. `download_and_prep.py`: Downloads the dataset for all categories, performs preprocessing, and adds embeddings. Saves a concatenated .parquet file with all categories.
2. `generate_feed_query.py`: Generates feed and query files for Vespa and Elasticsearch from the concatenated .parquet file.

## Overview

Broadly speaking, the data preparation involves the following steps:

1. Download the dataset
2. Preprocess the dataset
   1. Filter out the columns that are not needed
   2. Impute random prices for missing prices.
   3. Column renaming and type conversion.
   4. Clean description (strip brackets and convert to string).
3. Creating embeddings
   1. Using [snowflake-arctic-embed-xs](https://huggingface.co/Snowflake/snowflake-arctic-embed-xs) model.
   2. Make sure torch is installed with mps-accelerator support, see https://huggingface.co/docs/accelerate/en/usage_guides/mps
   3. Prompt: `Item: Title: {title} Description: {description}`
   4. 386-dimensional embeddings are generated.
4. Postprocessing
   1. Save the dataset per category to disk.
   2. Concatenate all categories to a single .parquet file.

After this, all feed and query files are generated from the concatenated .parquet file with the `generate_feed_query.py` script.

## Prepare the environment

First, install python dependencies.

It is recommended to use a virtual environment (i.e [pyenv](https://formulae.brew.sh/formula/pyenv))

Python version 3.11 is recommended, but any version between 3.8-3.12 should work.

```bash
pip install -r requirements.txt
```

## Running the scripts

### download_and_prep.py

Now you can run:

```bash
python download_and_prep.py
```

to download and prepare the data.
Note that this script will take several hours to run, as it needs to download the dataset and generate embeddings for each product.
To only run on a subset, the easiest way is to modify the `categories` list in the script.

Running the script will download and save the intermediate files to an `output-data` folder relative to this script.
The model will be downloaded and cached to `model_cache` folder relative to this script.
The final output will be saved to `output-data/ecommerce-{num_rows}.parquet`.

### generate_feed_query.py

After the data is prepared, you can run:

```bash
python generate_feed_query.py --basefile_path output-data/ecommerce-5M.parquet --mode both --num_samples 1000000 --num_queries 10000
```

to generate the feed and query files for Vespa and Elasticsearch.
This script will take the concatenated .parquet file and generate the feed and query files for Vespa and Elasticsearch.

These modes are available:

- `both`: Generates feed and query files for Vespa and Elasticsearch.
- `feed`: Generates only the feed files for both Vespa and Elasticsearch.
- `query`: Generates only the query files for both Vespa and Elasticsearch.

## Output

After running `generate_feed_query.py`, the following files will be generated in a new folder `output-data/{%Y%m%d-%H%M%S}`.
The folder will contain the following files:

### Feed files

- `es_feed-{num_samples}.json.zst`: Elasticsearch feed file.
- `vespa_feed-{num_samples}.json.zst`: Vespa feed file.

### Query files

For each of the query modes `weak_and`, `semantic` and `hybrid`, the following files will be generated:

- `vespa_queries_{mode}-{num_queries}.json.zst`: Vespa query file.
- `es_queries_{mode}-{num_queries}.json.zst`: Elasticsearch query file.

### Vespa feed format

Will be jsonl-formatted and compressed using `zstd` with compression level 1. 
Each line is a json object representing a document.

```json
{
    "put": "id:product:product::1",
    "fields": {
        "id": 1,
        "title": "Precision Plunger Bars for Cartridge Grips \u2013 93mm \u2013 Bag of 10 Plungers",
        "description": "The Precision Plunger Bars are designed to work seamlessly with the\u00a0Precision Disposable 1. 25\" Contoured Soft Cartridge Grips\u00a0and the\u00a0Precision Disposable 1\" Textured Soft Cartridge Grips\u00a0to drive cartridge needles with vice style or standard tattoo machine setups. These plunger bars are manufactured from 304 Stainless Steel and feature a brass tip. The plungers are sold in a bag of ten in your choice of 88mm, 93mm, or 98mm length.",
        "price": 1,
        "average_rating": 4.3,
        "category": "All_Beauty",
        "embedding": [
            0.0082836002,
            # ... 386 floats
            0.0030409386
        ]
    }
}
```

### Elasticsearch feed format

Will be newline-delimited JSON, compressed using `zstd` with compression level 1,
with alternating lines of action and data source, see [https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html).

```json
{"index":{"_index":"product","_id":1}}
{"title":"Precision Plunger Bars for Cartridge Grips \u2013 93mm \u2013 Bag of 10 Plungers","description":"The Precision Plunger Bars are designed to work seamlessly with the\u00a0Precision Disposable 1. 25\" Contoured Soft Cartridge Grips\u00a0and the\u00a0Precision Disposable 1\" Textured Soft Cartridge Grips\u00a0to drive cartridge needles with vice style or standard tattoo machine setups. These plunger bars are manufactured from 304 Stainless Steel and feature a brass tip. The plungers are sold in a bag of ten in your choice of 88mm, 93mm, or 98mm length.","price":1,"average_rating":4.3,"category":"All_Beauty","embedding":[0.0082836002, ... 0.0030409386]}
```
