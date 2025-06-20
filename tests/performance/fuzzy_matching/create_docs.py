# Copyright Vespa.ai. All rights reserved.

import argparse as ap
import json
import math
import random


def read_dictionary(file_name, dict_docs):
    result = []
    with open(file_name, 'r') as file:
        for line in file:
            parts = line.strip().split('\t')
            word = parts[0]
            raw_freq = int(parts[1])
            scaled_freq = min(1.0, raw_freq / dict_docs)
            
            result.append((word, raw_freq, scaled_freq))
    return result


def populate_docs(word_dict, num_docs):
    docs = [[] for _ in range(num_docs)]
    i = 0
    for entry in word_dict:
        docs_with_word = math.ceil(num_docs * entry[2])
        for _ in range(docs_with_word):
            docs[i].append(entry[0])
            i += 1
            if i >= len(docs):
                i = 0
    random.shuffle(docs)
    return docs


def populate_filters(num_docs):
    filters = []
    for i in range(num_docs):
        doc_filter = []
        # These values represent how many documents of the corpus are returned per thousand
        # when querying for one of these values.
        for f in [1, 10, 100, 500, 900]:
            if (i % 1000) < f:
                doc_filter.append(f)
        filters.append(doc_filter)
    random.shuffle(filters)
    return filters


def docs_to_json(docs, filters):
    print('[')
    suffix = ','
    for i, entry in enumerate(docs):
        doc = {'put': 'id:test:test::%i' % i, 'fields': {'id': i, 'filter': filters[i], 'content': entry}}
        if i == (len(docs) - 1):
            suffix = ''
        print(json.dumps(doc) + suffix)
    print(']')


parser = ap.ArgumentParser()
parser.add_argument('dictfile', type=str)
parser.add_argument('-d', '--dictdocs', type=int, default=20)
parser.add_argument('-c', '--createdocs', type=int, default=10)
args = parser.parse_args()
random.seed(1234)

word_dict = read_dictionary(args.dictfile, args.dictdocs)
random.shuffle(word_dict)
docs = populate_docs(word_dict, args.createdocs)
filters = populate_filters(args.createdocs)
docs_to_json(docs, filters)

