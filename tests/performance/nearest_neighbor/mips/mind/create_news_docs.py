# Copyright Vespa.ai. All rights reserved.

import csv
import json
import sys

# Example usage: python3 create_news_docs.py news_embeddings.tsv > news_docs.json
tsv_file = sys.argv[1]

print('[')
with open(tsv_file, 'r') as f_in:
    reader = csv.reader(f_in, delimiter='\t')
    first = True
    for row in reader:
        news_id = row[0]
        embedding = [float(x) for x in row[1].split(',')]
        doc = {"put": "id:news:news::%s" % news_id,
                      "fields": {"id": news_id,
                                 "embedding": embedding}}
        if not first:
          sys.stdout.write(',\n')
        json.dump(doc, sys.stdout)
        first = False
print(']')

