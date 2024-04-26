# Dataprep

This folder contains the scripts to prepare the data for the hybrid search benchmark.
The data is based on this dataset: https://huggingface.co/datasets/McAuley-Lab/Amazon-Reviews-2023.

## Overview

Broadly speaking, the data preparation involves the following steps:

1. Download the dataset
2. Preprocess the dataset
   1. Filter out the columns that are not needed
   2. Remove rows with missing description.
   3. Impute random prices for missing prices.
   4. Column renaming and type conversion.
3. Creating embeddings
   1. Using [snowflake-arctic-embed-xs](https://huggingface.co/Snowflake/snowflake-arctic-embed-xs) model.
   2. Prompt: `Item: Title: {title} Description: {description}`
   3. 386-dimensional embeddings are generated.
4. Postprocessing
   1. Convert to vespa/es format.
   2. Save the dataset per category to disk. 
5. TODO: Merging to one final dataset
   1. Merge all the category datasets into one final dataset.
   2. Add `category` field and make sure `id` is regenerated to be unique.
   3. Save the final dataset to disk.

## Running the script

Running the script will download and save the intermediate files to an `output-data` folder relative to this script.
The model will be downloaded and cached to `model_cache` folder relative to this script.

First, install python dependencies.

It is recommended to use a virtual environment (i.e [pyenv](https://formulae.brew.sh/formula/pyenv))

```bash
pip install -r requirements.txt
```

Then, run the `python download_and_prep.py` script to download and prepare the data.
Optional command line arguments:

- `--overwrite: bool` - Whether to overwrite the existing files.
- `--n_processes: int` - Number of processes to use for parallel processing.
