#!/bin/bash

# Variables
ZST_FILE="../dataprep/output-data/final/es_feed-1M.json.zst"
OUTPUT_DIR="./output_chunks"
ES_ENDPOINT="http://localhost:9200/_bulk"
CHUNK_SIZE=10000 # Make sure not to exceed 100MB, which is limit for ES Bulk API
LOG_FILE="upload_results.log"
UNZIPPED_FILE="${OUTPUT_DIR}/$(basename $ZST_FILE .zst)"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Record the start time
START_TIME=$(date +%s)

# Check if the unzipped file already exists
if [ -f "$UNZIPPED_FILE" ]; then
    echo "$UNZIPPED_FILE already exists. Skipping unzipping."
else
    echo "Unzipping $ZST_FILE..."
    unzstd -c $ZST_FILE -o $UNZIPPED_FILE
fi

# Split the unzipped file into chunks of 
split -l $CHUNK_SIZE $UNZIPPED_FILE ${OUTPUT_DIR}/chunk_

# Initialize or clear the log file
> $LOG_FILE

# Loop through each chunk and send it to the Elasticsearch endpoint
for CHUNK in ${OUTPUT_DIR}/chunk_*
do
    echo "Uploading $CHUNK to Elasticsearch"
    RESPONSE=$(curl -s -H "Content-Type: application/x-ndjson" -XPOST $ES_ENDPOINT --data-binary "@$CHUNK")

    # Extract and log relevant information using jq
    TOOK=$(echo $RESPONSE | jq '.took')
    ERRORS=$(echo $RESPONSE | jq '.errors')
    echo "Chunk: $CHUNK, Took: $TOOK ms, Errors: $ERRORS" | tee -a $LOG_FILE
done

# Record the end time
END_TIME=$(date +%s)

# Calculate total upload time
TOTAL_TIME=$((END_TIME - START_TIME))

# Cleanup chunk files after upload
echo "Cleaning up chunk files..."
rm ${OUTPUT_DIR}/chunk_*

# Echo total upload time. Also write to log file.
echo "Total upload time: $TOTAL_TIME seconds" | tee -a $LOG_FILE
echo "Data upload and cleanup complete." | tee -a $LOG_FILE
