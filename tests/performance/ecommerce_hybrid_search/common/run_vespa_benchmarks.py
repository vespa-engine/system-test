# %% [markdown]
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# 

# %% [markdown]
# # Vespa
# 
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

feed_file_vespa = os.path.join(OUTPUT_DIR, f"vespa_feed-{run_size.value}.json.zst")
query_files = {query_mode.value: os.path.join(OUTPUT_DIR, f"vespa_queries-{query_mode.value}-10k.json.zst") for query_mode in Mode}

query_files, feed_file_vespa


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
if not os.path.exists(feed_file_vespa):
    download_file(f"{download_base_url}/vespa_feed-{run_size.value}.json.zst", feed_file_vespa)

# %% [markdown]
# # Vespa
# 

# %% [markdown]
# ## Running the Vespa docker container
# 
# Verify that docker/podman engine is running
# 
# Recommended resource configuration:
# 
# - 8 CPUs
# - 25 GB RAM
# - 100 GB+ disk space
# 

# %%
import docker

client = docker.from_env()
docker_network = "my_network"
container_name = "vespa-ecommerce"
# Create a network if it does not exist
try:
    client.networks.get(docker_network)
    print(f"Network {docker_network} already exists")
except docker.errors.NotFound:
    client.networks.create(docker_network, driver="bridge")
    print(f"Network {docker_network} created")

container = client.containers.run(
    "vespaengine/vespa",
    detach=True,
    ports={"8080/tcp": 8080, "19071/tcp": 19071},
    network=docker_network,
    name=container_name,
)
# Wait until container is ready
container.reload()

# %% [markdown]
# ## Deploy the Vespa application
# 

# %%
from vespa.deployment import VespaDocker

app_package_path = "../app/"

vespa_docker = VespaDocker(container=container, port=8080)
app_name = "ecommerce"

app = vespa_docker.deploy_from_disk(
    application_name=app_name, application_root=app_package_path
)

# %% [markdown]
# ## Feed data to Vespa
# 

# %%
import zstandard as zstd
import json
import os

def unzstd(file_path, remove_decompressed_file=True):
    with open(file_path, 'rb') as compressed:
        decomp = zstd.ZstdDecompressor()
        with open(file_path.replace(".zst", ""), 'wb') as destination:
            decomp.copy_stream(compressed, destination)
    if remove_decompressed_file:
        os.remove(file_path)
    return file_path.replace(".zst", "")

if not os.path.exists(feed_file_vespa.replace(".zst", "")):
    unzstd(feed_file_vespa)

# %%
import subprocess

# Use vespa CLI (vespa feed --progress 10) to feed data
set_target_command = "vespa config set target local"
feed_command = f"vespa feed --progress 10 {feed_file_vespa.replace('.zst', '')}"

# Set target to local
subprocess.run(set_target_command, shell=True, capture_output=True, text=True)

# Feed data
feed_output = subprocess.run(feed_command, shell=True, capture_output=True, text=True)

# Print the output of the feed command
print("Feed Command Output:")
print(feed_output.stdout)
print(feed_output.stderr)

# %%
import json


feed_result = json.loads(feed_output.stdout)
print(json.dumps(feed_result, indent=2))

# %%
assert int(feed_result["feeder.ok.count"]) == int(run_size)

# %% [markdown]
# ## Running fbench against Vespa-container
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
        "output_file": os.path.join(folder_name, f"fbench_output_vespa_{query_mode.value}.txt"),
        "result_file": os.path.join(folder_name, f"fbench_results__vespa_{query_mode.value}.txt"),
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
        command=[
            "-c",
            "0",
            "-s",
            "30",
            "-n",
            "1",
            "-q",
            config["query_file"],
            "-P",
            "-o",
            config["output_file"],
            container_name,
            "8080",
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

# %% [markdown]
# ### Cleanup and remove Vespa container
# 

# %%
vespa_docker.container.stop()
vespa_docker.container.remove()
