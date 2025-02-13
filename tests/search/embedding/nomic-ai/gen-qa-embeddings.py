#!/usr/bin/python3.11

import sys
import json
import torch
from transformers import AutoTokenizer, AutoModel

def mean_pooling(model_output, attention_mask):
    token_embeddings = model_output[0]
    input_mask_expanded = (
        attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    )
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(
        input_mask_expanded.sum(1), min=1e-9
    )

queries = [ ]
documents = [ ]
j = json.load(open('q-and-a.json'))
for o in j:
    queries.append('search_query: ' + o['qtext'])
    documents.append('search_document: ' + o['dtext'])

tokenizer = AutoTokenizer.from_pretrained("nomic-ai/modernbert-embed-base")
model = AutoModel.from_pretrained("nomic-ai/modernbert-embed-base")

encoded_queries   = tokenizer(queries,   padding=True, truncation=True, return_tensors="pt")
encoded_documents = tokenizer(documents, padding=True, truncation=True, return_tensors="pt")

with torch.no_grad():
    queries_outputs = model(**encoded_queries)
    documents_outputs = model(**encoded_documents)

query_embeddings = mean_pooling(queries_outputs, encoded_queries["attention_mask"])
doc_embeddings = mean_pooling(documents_outputs, encoded_documents["attention_mask"])

torch.set_printoptions(precision=6)
torch.set_printoptions(threshold=25)
torch.set_printoptions(edgeitems=5)
torch.set_printoptions(linewidth=120)
torch.set_printoptions(sci_mode=False)

d = doc_embeddings
q = query_embeddings
for i in range(0, len(j)):
    qe = torch.cat((q[i][:6], q[i][-5:])).tolist()
    qe[5] = 0
    j[i]['q_emb'] = qe
    de = torch.cat((d[i][:6], d[i][-5:])).tolist()
    de[5] = 0
    j[i]['d_emb'] = de

json.dump(j, sys.stdout, indent=4)
print("")
