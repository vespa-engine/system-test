import json
import sys
import numpy

for doc in range(0, 1):
	tokens = dict()
	for t in range(0,32):
		vector = numpy.random.rand(128)
		l2_norm = numpy.linalg.norm(vector)
		normalized_vector = vector / l2_norm
		tokens[t] = normalized_vector.tolist()
	query = {
		'query': 'sddocname:product',
		'hits': 0,
		'input.query(qt)': tokens
	}
	print("/search/")	
	print(json.dumps(query))

