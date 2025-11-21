#!/usr/bin/env python3
# Copyright Vespa.ai. All rights reserved.

import json
import random
import string
import sys

# Use fixed seed for reproducible test data
random.seed(42)

def random_string(min_len, max_len):
    length = random.randint(min_len, max_len)
    return ''.join(random.choices(string.ascii_letters + string.digits + ' ', k=length))

def generate_doc(doc_id):
    metadata = {random_string(5, 15): random_string(20, 100) for _ in range(random.randint(50, 150))}
    scores = {random_string(5, 15): random.randint(0, 1000) for _ in range(random.randint(50, 150))}
    tags = {random_string(5, 20): random.randint(1, 100) for _ in range(random.randint(50, 200))}

    return {
        "put": f"id:map_wset:map_wset::{doc_id}",
        "fields": {
            "id": doc_id,
            "metadata": metadata,
            "scores": scores,
            "tags": tags
        }
    }

def main():
    num_docs = int(sys.argv[1]) if len(sys.argv) > 1 else 3200

    docs = [generate_doc(i) for i in range(num_docs)]

    print(json.dumps(docs, separators=(',', ':')))

if __name__ == "__main__":
    main()
