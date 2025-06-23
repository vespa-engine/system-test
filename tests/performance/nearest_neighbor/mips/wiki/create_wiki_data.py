# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import json as json
import pandas as pd
import sys
import urllib.parse

# Prerequisites:
# pip install pandas
# pip install pyarrow

def read_data_frame(files):
    parts = []
    for f in files:
        # The following columns exist in the data set:
        # id           int32
        # title        object
        # text         object
        # url          object
        # wiki_id      int32
        # views        float32
        # paragraph_id int32
        # langs        int32
        # emb          object
        cols = ['wiki_id', 'paragraph_id', 'emb']
        parts.append(pd.read_parquet(f, engine='pyarrow', columns=cols))

    df = pd.concat(parts, ignore_index=True)
    df = df.sort_values(['wiki_id', 'paragraph_id'], ascending = [True, True])
    return df


def get_doc(wiki_id, paragraph_id, embedding):
    return { 'put': 'id:paragraph:paragraph::%s_%s' % (wiki_id, paragraph_id),
             'fields': {
                 'id': (wiki_id * 1000) + paragraph_id,
                 'embedding': embedding
                 }
            }


def create_docs(df, max_docs):
    print('[')
    cnt = 0
    for index, row in df.iterrows():
        wiki_id = int(row['wiki_id'])
        paragraph_id = int(row['paragraph_id'])
        embedding = row['emb'].tolist()
        if cnt > 0:
          sys.stdout.write(',\n')
        json.dump(get_doc(wiki_id, paragraph_id, embedding), sys.stdout)
        cnt += 1
        if cnt >= max_docs:
            break
    print(']')


def create_queries(df, max_queries):
    cnt = 0
    # Iterate the data set in reverse order to avoid overlap with the document set.
    for index, row in df.iloc[::-1].iterrows():
        embedding = row['emb'].tolist()
        target_hits = 100
        yql = 'select * from sources * where {targetHits:%s}nearestNeighbor(embedding,paragraph)' % target_hits
        params = { 'yql': yql,
                   'input.query(paragraph)': str(embedding),
                   'presentation.summary': 'minimal',
                   'hits': 10
        }
        prefix = '/search/?'
        print(prefix + urllib.parse.urlencode(params))
        cnt += 1
        if cnt >= max_queries:
            break


def create_vectors(df, max_vectors):
    cnt = 0
    # Iterate the data set in reverse order to avoid overlap with the document set.
    for index, row in df.iloc[::-1].iterrows():
        embedding = row['emb'].tolist()
        print(urllib.parse.quote(str(embedding)))
        cnt += 1
        if cnt >= max_vectors:
            break


max_count = 10000
data_type = 'docs'
if len(sys.argv) >= 2:
    data_type = sys.argv[1]

if len(sys.argv) >= 3:
    max_count = int(sys.argv[2])

df = read_data_frame(['train-00000-of-00004-1a1932c9ca1c7152.parquet',
                      'train-00001-of-00004-f4a4f5540ade14b4.parquet',
                      'train-00002-of-00004-ff770df3ab420d14.parquet',
                      'train-00003-of-00004-85b3dbbc960e92ec.parquet'])

if data_type == 'docs':
    create_docs(df, max_count)
elif data_type == 'queries':
    create_queries(df, max_count)
elif data_type == 'vectors':
    create_vectors(df, max_count)
else:
    print("Usage: " + sys.argv[0] + " <type> <max_count>")
    exit(1)


