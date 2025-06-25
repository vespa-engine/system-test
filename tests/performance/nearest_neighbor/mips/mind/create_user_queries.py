# Copyright Vespa.ai. All rights reserved.

import csv
import json
import numpy as np
import sys
import urllib.parse

# Example usage: python3 create_user_queries.py user_embeddings.tsv 1000 > user_queries.json"

tsv_file = sys.argv[1]
num_queries = int(sys.argv[2])
only_vectors = False
if len(sys.argv) >= 4 and sys.argv[3] == 'vectors':
    only_vectors = True

with open(tsv_file, 'r') as f_in:
    reader = csv.reader(f_in, delimiter='\t')
    cnt = 0
    for row in reader:
        # The user id at row[0] is not needed
        embedding = [float(x) for x in row[1].split(',')]

        # The average vector length is 0.0637 for user_embeddings.large.tsv
        # Ignore short vectors (some has length 0.0):
        length = np.linalg.norm(embedding)
        if length < 0.001:
            continue

        target_hits = 100
        yql = 'select * from sources * where {targetHits:%s}nearestNeighbor(embedding,user)' % target_hits
        params = { 'yql': yql,
                   'input.query(user)': str(embedding),
                   'presentation.summary': 'minimal',
                   'hits': 10
        }
        prefix = '/search/?'
        if only_vectors:
            print(urllib.parse.quote(str(embedding)))
        else:
            print(prefix + urllib.parse.urlencode(params))
        cnt += 1
        if cnt >= num_queries:
            break

