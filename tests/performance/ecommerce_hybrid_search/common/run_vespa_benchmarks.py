# %% [markdown]
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# 

# %% [markdown]
# # Vespa
# 

# %% [markdown]
# ## Starting the Vespa docker container
# 
# Be sure that your docker engine is running, and has at least 24GB of memory allocated to it.
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
#!zstd -d -f ../dataprep/output-data/final/vespa_feed-20k.json.zst -o ../dataprep/output-data/final/vespa_feed-20k.json

# %%
# !vespa config set target local
# unzstd the file
#!zstd -d -f ../dataprep/output-data/final/vespa_feed-1M.json.zst -o ../dataprep/output-data/final/vespa_feed-1M.json
# !vespa feed --progress 5 ../dataprep/output-data/final/vespa_feed-20k.json

# %% [markdown]
# ## Querying Vespa
# 

# %% [markdown]
# ### BM25
# 

# %%
bm25_query = get_single_query(application="vespa", query_mode="weak_and")
bm25_query

# %%
from vespa.io import VespaQueryResponse

response: VespaQueryResponse = app.query(
    # Update to medium presentation summary
    body={**bm25_query, "presentation.summary": "medium"}
)
print(json.dumps(response.hits[:3], indent=4))

# %% [markdown]
# ### Semantic search
# 

# %%
semantic_query = get_single_query(application="vespa", query_mode="semantic")
semantic_query

# %%
response: VespaQueryResponse = app.query(
    # Update to medium presentation summary
    body={**semantic_query, "presentation.summary": "medium"}
)
print(json.dumps(response.hits[:3], indent=4))

# %% [markdown]
# ### Hybrid query
# 

# %%
hybrid_query = get_single_query(application="vespa", query_mode="hybrid")
hybrid_query

# %%
response: VespaQueryResponse = app.query(
    # Update to medium presentation summary
    body={**hybrid_query, "presentation.summary": "medium"}
)
print(json.dumps(response.hits[:3], indent=4))

# %% [markdown]
# ## Running fbench against Vespa-container
# 

# %%
# !for f in ../dataprep/output-data/final/vespa_queries-*-10k.json.zst; do zstd -d -f "$f" -o "${f%.zst}"; done

# %%
# Define the options and base filenames
options = ["weak_and", "semantic", "hybrid"]
base_query_file = "vespa_queries-{}-10k.json"
base_output_file = "fbench_output_vespa_{}.txt"
result_file = "fbench_results_vespa_{}.txt"
# Generate the configurations dynamically
configs = [
    {
        "option": option,
        "query_file": base_query_file.format(option),
        "output_file": base_output_file.format(option),
        "result_file": result_file.format(option),
    }
    for option in options
]

# Loop through each configuration and run the container
for config in configs:
    print(f"Running fbench in container for {config['option']} queries")
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
            "-D",
            container_name,
            "8080",
        ],
        volumes={
            "/Users/thomas/Repos/system-test/tests/performance/ecommerce_hybrid_search/dataprep/output-data/final": {
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
    print(f"Output for {config['option']} queries:\n{result}")
    # Save results to a file
    with open(config["result_file"], "w") as file:
        file.write(result)

# %% [markdown]
# ### Cleanup and remove Vespa container
# 

# %%
vespa_docker.container.stop()
vespa_docker.container.remove()

# %% [markdown]
# ### Compare fbench output
# 

# %%
import json
from typing import Dict
import seaborn as sns
import matplotlib.pyplot as plt
import logging


def clean_results(result_file_path: str) -> Dict:
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
        # Loop through each line in the file
        for line in lines:
            # keep only lines starting with {}
            if line.startswith("{"):
                # Load the line as a dictionary
                result_dict = json.loads(line)
                if application == "es":
                    # Extract hits from the dictionary
                    hits = result_dict["hits"]["hits"]
                    # Exctract id and score (named relevance) from each hit
                    individual_results = [
                        {"id": int(hit["_id"]), "relevance": hit["_score"]}
                        for hit in hits
                    ]
                elif application == "vespa":
                    # Extract the query_id from the dictionary
                    children = result_dict["root"]["children"]
                    individual_results = [
                        {"id": child["fields"]["id"], "relevance": child["relevance"]}
                        for child in children
                    ]
                # Assert length of results
                assert len(individual_results) <= 10, individual_results
                all_results[query_id_counter] = individual_results
                query_id_counter += 1
    return all_results


def calculate_overlaps(
    vespa_fbench_output_path: str, es_fbench_output_path: str
) -> float:
    vespa_results: dict = clean_results(vespa_fbench_output_path)
    print(f"Vespa results cleaned for {query_mode} - length: {len(vespa_results)}")
    es_results: dict = clean_results(es_fbench_output_path)
    print(f"Elasticsearch results cleaned for {query_mode} - length: {len(es_results)}")
    # Now we want to calculate the number of overlapping results in the top 10 for each query
    # We need to take only the lowest number of queries across the two systems
    min_queries = min(len(vespa_results), len(es_results))
    # Initialize the overlap counter
    overlap = {}
    # Loop through each query
    for query_id in range(1, min_queries + 1):
        # Get the top 10 results for each system
        vespa_top_10 = {result["id"] for result in vespa_results[query_id][:10]}
        es_top_10 = {result["id"] for result in es_results[query_id][:10]}
        # Calculate the overlap
        overlap[query_id] = len(vespa_top_10.intersection(es_top_10)) / 10
    return overlap


def plot_overlap(overlap: dict):
    # Plot a histogram of the overlap
    # One bin per 0.1 interval

    bins = [x / 10 for x in range(11)]
    # Create the histogram
    sns.histplot(overlap.values(), bins=bins)
    # Set the title
    plt.title(f"Overlap in the top 10 results for weak_and and {query_mode}")
    # Set a legend with total number of queries
    plt.legend([f"Evaluated queries: {len(overlap)}"])
    # Add another legend in center of plot with average overlap (to 2 decimal places)
    plt.text(
        0.5,
        0.5,
        f"Average overlap: {sum(overlap.values())/len(overlap):.2f}",
        horizontalalignment="center",
        verticalalignment="center",
        transform=plt.gca().transAxes,
    )
    # Show the plot
    return plt.show()


# File path to the uploaded file
querymodes = ["weak_and", "semantic", "hybrid"]

for query_mode in querymodes:
    vespa_fbench_output_path = (
        f"../dataprep/output-data/final/fbench_output_vespa_{query_mode}.txt"
    )
    es_fbench_output_path = (
        f"../dataprep/output-data/final/fbench_output_es_{query_mode}.txt"
    )
    overlap = calculate_overlaps(vespa_fbench_output_path, es_fbench_output_path)
    plot_overlap(overlap)


# %%
