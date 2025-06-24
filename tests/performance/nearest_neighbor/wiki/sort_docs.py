o# Copyright Vespa.ai. All rights reserved.

import json
import sys

data = json.load(sys.stdin)

# Sort the array of objects on the field "id"
sorted_data = sorted(data, key=lambda x: x['id'])

print('[')
delim = ''
for obj in sorted_data:
    print(delim + json.dumps(obj))
    delim = ','

print(']')
