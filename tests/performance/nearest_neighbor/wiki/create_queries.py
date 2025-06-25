# Copyright Vespa.ai. All rights reserved.

import json
import sys
import urllib.parse

for doc in json.load(sys.stdin):
    embedding = doc['fields']['embedding']['values']
    target_hits=100
    yql = 'select * from sources * where {targetHits:%s}nearestNeighbor(embedding,question)' % target_hits
    question = str(embedding)
    params = { 'yql': yql,
               'input.query(question)': question,
               'presentation.summary': 'minimal',
               'hits': 10
             }
    prefix = '/search/?'
    print(prefix + urllib.parse.urlencode(params))
