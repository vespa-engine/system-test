# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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

for doc in docs:
  doc_id = doc['_id']
  emb = doc['emb']
  embeddings = dict()
  for dims in [256,384,512,768,1024]:
    mrl_vector = get_mrl_vector(emb, dims)
    binary_vector = binary_quantize_vector(mrl_vector)
    scalar_vector = scalar_quantize_vector(mrl_vector)
    for distance in ['angular','euclidean','dotproduct', "prenormalized_angular"]:
      field = f'float_{dims}_{distance}'
      with open(f"queries/float-{dims}-{distance}.txt", "w") as f:
        query = {
          'yql': f'select id from vector where {{targetHits:100}}nearestNeighbor({field},float_q_{dims})',
          'hits': 1,
          "ranking": field,
          f'input.query(float_q_{dims})': mrl_vector.tolist()
        }
        f.write("/search/\n")
        f.write(json.dumps(query) + "\n")
    for distance in ['angular','euclidean','dotproduct']:
        field = f'scalar_int8_{dims}_{distance}'
        with open(f"queries/scalar-int8-{dims}-{distance}.txt", "w") as f:
          query = {
            'yql': f'select id from vector where {{targetHits:100}}nearestNeighbor({field},int8_q_{dims})',
            'hits': 1,
            "ranking": field,
            f'input.query(int8_q_{dims})': scalar_vector.tolist(),
          
          }
          f.write("/search/\n")
          f.write(json.dumps(query) + "\n")

    if dims > 384:
        binary_dims = int(dims/8)
        with open(f"queries/binary-int8-{binary_dims}-hamming.txt", "w") as f:
          field = f'binary_int8_{binary_dims}_hamming'
          query = {
            'yql': f'select id from vector where {{targetHits:100}}nearestNeighbor({field},int8_q_{binary_dims})',
            'hits': 1,
            "ranking": field,
            f'input.query(int8_q_{binary_dims})': binary_vector.tolist()
          }h
          f.write("/search/\n")
          f.write(json.dumps(query) + "\n")
  break
