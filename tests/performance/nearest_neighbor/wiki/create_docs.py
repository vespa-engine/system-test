# Copyright Vespa.ai. All rights reserved.

import sys
import pandas as pd
import json as json

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
        cols = ['wiki_id', 'paragraph_id', 'title', 'text']
        parts.append(pd.read_parquet(f, engine='pyarrow', columns=cols))

    df = pd.concat(parts, ignore_index=True)
    df = df.sort_values(['wiki_id', 'paragraph_id'])
    count = len(df.index)
    uniq = df.wiki_id.nunique()
    return df


def wiki_doc(wiki_id, title, text):
    return { 'put': 'id:wiki:wiki::%s' % wiki_id,
             'fields': {
                 'id': wiki_id,
                 'title': title,
                 'text': text,
                 }
            }

def paragraph_doc(wiki_id, paragraph_id, title, text):
    return { 'put': 'id:paragraph:paragraph::%s_%s' % (wiki_id, paragraph_id),
             'fields': {
                 'id': wiki_id,
                 'paragraph': paragraph_id,
                 'title': title,
                 'text': text,
                 }
            }

# This document contains illegal code points, so just skip it
# Exception in thread "main" com.yahoo.document.json.JsonReaderException: Error in document 'id:wiki:wiki::904391' - could not parse field 'text' of type 'Array<string>': The string field value contains illegal code point 0x10FFFE
illegal_id = 904391

def create_wiki_docs(df, max_docs):
    title = None
    wiki_id = -1
    text = []
    docs = 0

    print('[')
    for index, row in df.iterrows():
        next_wiki_id = int(row['wiki_id'])
        is_done = False
        if (wiki_id != -1) and (next_wiki_id != wiki_id):
            if wiki_id != illegal_id:
                docs += 1
                is_done = docs >= max_docs
                print(json.dumps(wiki_doc(wiki_id, title, text)) + ('' if is_done else ','))
            text = []
        if is_done:
            break
        wiki_id = next_wiki_id
        title = row['title']
        text.append(row['text'])

    if text:
        print(json.dumps(wiki_doc(wiki_id, title, text)))

    print(']')


def create_paragraph_docs(df, max_docs):
    print('[')
    delim = ''
    docs = 0
    for index, row in df.iterrows():
        wiki_id = int(row['wiki_id'])
        if wiki_id != illegal_id:
            paragraph_id = int(row['paragraph_id'])
            title = row['title']
            text = row['text']
            print(delim + json.dumps(paragraph_doc(wiki_id, paragraph_id, title, text)))
            delim = ','
            docs += 1
            if docs >= max_docs:
                break
    print(']')


max_docs = 1000000
create_wiki = True
if len(sys.argv) >= 2:
    type = sys.argv[1]
    if type == 'wiki':
        create_wiki = True
    elif type == 'paragraph':
        create_wiki = False
    else:
        print("Usage: " + sys.argv[0] + " <type> <max_docs>")
        exit(1)

if len(sys.argv) >= 3:
    max_docs = int(sys.argv[2])

df = read_data_frame(['train-00000-of-00004-1a1932c9ca1c7152.parquet',
                      'train-00001-of-00004-f4a4f5540ade14b4.parquet',
                      'train-00002-of-00004-ff770df3ab420d14.parquet',
                      'train-00003-of-00004-85b3dbbc960e92ec.parquet'])

if create_wiki:
    create_wiki_docs(df, max_docs)
else:
    create_paragraph_docs(df, max_docs)
