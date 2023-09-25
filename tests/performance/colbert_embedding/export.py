import json
import sys

feed = []
for line in sys.stdin:
    doc = json.loads(line)
    feed.append(doc)
print(json.dumps(feed))
