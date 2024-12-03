# Copyright Vespa.ai. All rights reserved.

import argparse
import json
import random
import string
import sys

parser = argparse.ArgumentParser(description='Creates a JSON update for the payload field for each document id from standard in')
parser.add_argument('--payload_bytes', type=int, default=600)
parser.add_argument('--clear', action='store_true')
args = parser.parse_args()

payload_bytes = args.payload_bytes
base64_length = int(payload_bytes * 8 / 6)
num_payloads = 1000
random.seed(1234)
clear = args.clear

payloads = [
    ''.join(random.choices(string.ascii_letters + string.digits, k=base64_length))
    for _ in range(num_payloads)
]

i = 0
for line in sys.stdin:
    docid = line.strip()
    update = {
        "update": docid,
        "fields": {
            "payload": {
                "assign": None if clear else payloads[i % len(payloads)]
            }
        }
    }
    i += 1
    print(json.dumps(update))

