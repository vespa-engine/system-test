# %% [markdown]
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# 

# %% [markdown]
# # ES
# 

# %% [markdown]
# ## Defining our input files
# 

# %%
import os 
from enum import Enum

# Define RunSize as enum (mini, medium, full)
# Make it possible to get bot string and int value
class RunSize(Enum):
    MINIMAL = "100k"
    MEDIUM = "1M"
    FULL = "5M"
    
    def __int__(self):
        return {
            RunSize.MINIMAL: 100000,
            RunSize.MEDIUM: 1000000,
            RunSize.FULL: 5000000
        }[self]

# Define run size as RunSize
run_size = RunSize.MINIMAL

# Define modes as enum (weak_and, hybrid, semantic)
class Mode(Enum):
    WEAK_AND = "weak_and"
    HYBRID = "hybrid"
    SEMANTIC = "semantic"

# Output dir is ../dataprep/output-data/{mode}
OUTPUT_DIR = os.path.join(os.path.dirname(os.getcwd()), "dataprep/output-data", run_size.value)

# Create output dir if it does not exist
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

feed_file_es = os.path.join(OUTPUT_DIR, f"es_feed-{run_size.value}.json.zst")
query_files = {query_mode.value: os.path.join(OUTPUT_DIR, f"es_queries-{query_mode.value}-10k.json.zst") for query_mode in Mode}

query_files, feed_file_es

# %% [markdown]
# ## Downloading data files
# 

# %%
import requests
import shutil
import pathlib
from tqdm import tqdm

download_base_url = "https://data.vespa.oath.cloud/tests/performance/ecommerce_hybrid_search"

def download_file(url, file_path):
    try:
        response = requests.get(url, stream=True)
        total_size_in_bytes= int(response.headers.get('content-length', 0))
        progress_bar = tqdm(total=total_size_in_bytes, unit='iB', unit_scale=True)
        if response.status_code == 200:
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=1024):
                    progress_bar.update(len(chunk))
                    f.write(chunk)
            progress_bar.close()
        else:
            print(f"Failed to download {url}. Status code: {response.status_code}")
    except Exception as e:
        print(f"Failed to download {url} to {file_path}")
        print(e)

# Download files if they do not exist
for query_mode, query_file in query_files.items():
    if not os.path.exists(query_file):
        print(f"Downloading {query_file}")
        download_file(f"{download_base_url}/{pathlib.Path(query_file).name}", query_file)

# Download feed file if it does not exist
if not os.path.exists(feed_file_es):
    download_file(f"{download_base_url}/es_feed-{run_size.value}.json.zst", feed_file_es)

# %% [markdown]
# ## Running the Elasticsearch docker container
# 

# %% [markdown]
# ### Verify that docker/podman engine is running
# 
# Recommended resource configuration:
# 
# - 8 CPUs
# - 24 GB RAM
# - 100+ GB disk space
# 

# %%
import docker

client = docker.from_env()
docker_network = "my_network"

# Create a network if it does not exist
try:
    client.networks.get(docker_network)
    print(f"Network {docker_network} already exists")
except docker.errors.NotFound:
    client.networks.create(docker_network, driver="bridge")
    print(f"Network {docker_network} created")

container = client.containers.run(
    "docker.elastic.co/elasticsearch/elasticsearch:8.13.4",
    detach=True,
    remove=True,
    ports={"9200/tcp": 9200},
    network=docker_network,
    name="elasticsearch",
    environment=[
        "discovery.type=single-node",
        "xpack.security.enabled=false",
        "xpack.security.http.ssl.enabled=false",
        "xpack.license.self_generated.type=trial",
    ],
)
# Wait until container is ready
container.reload()

# %%
from elasticsearch import Elasticsearch
import json
import time

es = Elasticsearch("http://localhost:9200")
timeout = 30
while not es.ping():
    timeout -= 1
    if timeout == 0:
        raise TimeoutError("Elasticsearch is not ready")
    time.sleep(1)

# %%
index_name = "product"

# Delete the index if it exists
if es.indices.exists(index=index_name):
    es.indices.delete(index=index_name)

# %%
import pathlib
import json
# Load the mapping from the file. Parent directory (one level up from this file)/app_es
ES_INDEX_FILE = pathlib.Path(os.getcwd()).parent / "app_es" / "index-settings.json"

with open(ES_INDEX_FILE, "r") as file:
    index_settings = json.load(file)

# Create the index
es.indices.create(index=index_name, body=index_settings)

# %%
# Pretty-print the mapping
mapping = es.indices.get_mapping(index=index_name)
mapping.raw

# %% [markdown]
# ## Feed the data to the Elasticsearch container
# 

# %%
import os
import time
import requests
import json
import zstandard as zstd
from concurrent.futures import ThreadPoolExecutor, as_completed
import io

# Constants
ZST_FILE = feed_file_es
ES_ENDPOINT = "http://localhost:9200/_bulk?pretty&filter_path=took,errors,items.*.error"
CHUNK_SIZE = 12000  # Number of lines per chunk
NUM_THREADS = 4  # Default number of threads

# Function to upload a chunk
def upload_chunk(chunk_data, success_counter, failure_counter):
    try:
        print(f"Uploading chunk to Elasticsearch")
        response = requests.post(ES_ENDPOINT, headers={"Content-Type": "application/x-ndjson"}, data=chunk_data)
        response_data = response.json()

        took = response_data.get('took')
        errors = response_data.get('errors')
        if errors:
            raise ValueError(f"Errors occurred: {errors}")
        
        log_entry = f"Took: {took} ms, Errors: {errors}"
        print(log_entry)
        success_counter.append(True)
    except Exception as e:
        print(f"Failed to upload chunk: {e}")
        failure_counter.append(True)

# Split and upload function
def split_and_upload(zst_file, chunk_size):
    success_counter = []
    failure_counter = []

    with open(zst_file, 'rb') as compressed_file, zstd.ZstdDecompressor().stream_reader(compressed_file) as stream_reader:
        text_stream = io.TextIOWrapper(stream_reader, encoding='utf-8')
        chunk_data = []
        futures = []
        
        with ThreadPoolExecutor(max_workers=NUM_THREADS) as executor:
            for line in text_stream:
                chunk_data.append(line)
                if len(chunk_data) == chunk_size:
                    chunk = ''.join(chunk_data)
                    futures.append(executor.submit(upload_chunk, chunk, success_counter, failure_counter))
                    chunk_data = []
            
            # Submit the remaining lines if any
            if chunk_data:
                chunk = ''.join(chunk_data)
                futures.append(executor.submit(upload_chunk, chunk, success_counter, failure_counter))
            
            # Wait for all futures to complete
            for future in as_completed(futures):
                future.result()
    
    print(f"Upload complete: {len(success_counter)} chunks succeeded, {len(failure_counter)} chunks failed")

# Run the script
start_time = time.time()

# Split the file and upload in chunks
split_and_upload(ZST_FILE, CHUNK_SIZE)

# %%
es.indices.refresh(index=index_name)
refresh_result = es.cat.count(index=index_name, format="json")
refresh_result

# %%
end_time = time.time()
print(f"Total time: {end_time - start_time} seconds")


# %%
assert int(refresh_result[0]["count"]) == int(run_size)

# %% [markdown]
# ## Running fbench against ES-container
# 

# %% [markdown]
# Decompressing query-files
# 

# %%
import zstandard as zstd
import glob
import os

# Create a zstandard decompressor
decompressor = zstd.ZstdDecompressor()

# Decompress each file
for zst_file in query_files.values():
    output_file = zst_file.replace('.zst', '')
    with open(zst_file, 'rb') as compressed, open(output_file, 'wb') as decompressed:
        decompressor.copy_stream(compressed, decompressed)

print("Decompression completed.")

# %% [markdown]
# ### Docker command to run fbench against ES-container
# 

# %% [markdown]
# Create new folder for the output files. Use datetime to make it unique
# 

# %%
import datetime

dt_str = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
folder_name =f"fbench_output_{dt_str}"
output_folder = os.path.join(OUTPUT_DIR, folder_name)
os.makedirs(output_folder, exist_ok=True)


configs = [
    {
        "mode": query_mode.value,
        # Strip .zst extension from the query file. Use only filename without path
        "query_file": os.path.basename(query_files[query_mode.value]).replace('.zst', ''),
        "output_file": os.path.join(folder_name, f"fbench_output_{query_mode.value}.txt"),
        "result_file": os.path.join(folder_name, f"fbench_results_{query_mode.value}.txt"),
    }
    for query_mode in Mode
]
configs

# %%
# Loop through each configuration and run the container
for config in configs:
    print("#" * 80 + "\n")
    print(f"Running fbench in container for {config['mode']} queries")
    output = client.containers.run(
        image="vespaengine/vespa",
        entrypoint="/opt/vespa/bin/vespa-fbench",  # Set vespa-fbench as the entrypoint
        network=docker_network,
        # See https://docs.vespa.ai/en/operations/tools.html#vespa-fbench for the list of available options
        command=[
            "-c", # cycleTime
            "0",
            "-s", # Seconds to run the benchmark
            "30",
            "-n", # Number of clients in parallel
            "1",
            "-q", # Query file
            config["query_file"],
            "-P", # Post requests (GET is default)
            "-o", # Output file
            config["output_file"],
            "elasticsearch", # Hostname to run against
            "9200", # Port to run against
        ],
        volumes={
            OUTPUT_DIR: {
                "bind": "/files",
                "mode": "rw",
            }
        },
        working_dir="/files",
        detach=False,
        remove=True,
    )

    # Wait for the container to finish and print the output
    result = output.decode("utf-8")
    print(f"Output for {config['mode']} queries:\n{result}")
    # Save results to a file
    output_file = os.path.join(OUTPUT_DIR, config["result_file"])
    with open(output_file, "w") as file:
        file.write(result)

# %%
# Stop the ES container
container.stop()
container.remove()
