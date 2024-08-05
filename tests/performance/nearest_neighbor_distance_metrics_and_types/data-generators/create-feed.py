# Copyright Vespa.ai. All rights reserved.
from datasets import load_dataset
import numpy as np
import json


def get_mrl_vector(embedding, dim, type=np.float32):
  vector = np.array(embedding,dtype=np.float32)
  vector = vector[0:dim]
  vector = vector/np.linalg.norm(vector)
  return vector


def binary_quantize_vector(vector):
  return np.packbits(np.where(vector > 0, 1, 0)).astype(np.int8)

def scalar_quantize_vector(vector):
  return np.round(vector*127).astype(np.int8)

docs = load_dataset("Cohere/wikipedia-2023-11-embed-multilingual-v3", "nn", split="train")

feed_docs = []
print("[")
i = 0
for doc in docs:
  doc_id = doc['_id']
  i += 1
  emb = doc['emb']
  embeddings = dict()
  for dims in [256,384,512,768,1024]:
    mrl_vector = get_mrl_vector(emb, dims)
    binary_vector = binary_quantize_vector(mrl_vector)
    scalar_vector = scalar_quantize_vector(mrl_vector)
    for distance in ['angular','euclidean','dotproduct', "prenormalized_angular"]:
      embeddings[f'float_{dims}_{distance}'] = mrl_vector.tolist()
    for distance in ['angular','euclidean','dotproduct']:
        embeddings[f'scalar_int8_{dims}_{distance}'] = scalar_vector.tolist()
    if dims > 384:
        embeddings[f'binary_int8_{int(dims/8)}_hamming'] = binary_vector.tolist()
  
  json_doc = {
     "id": "id:doc:vector::" + doc_id,
     "fields": {
        "id": doc_id,
        **embeddings
      }
  }
  json_line = json.dumps(json_doc)
  if i < 500000:
    print(json_line + ",")  
  else:
    print(json_line)
    break
print("]") 
  