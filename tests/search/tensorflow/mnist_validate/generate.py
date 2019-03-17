#! /usr/bin/env python3
# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import json

from tensorflow.examples.tutorials.mnist import input_data

mnist = input_data.read_data_sets("/tmp/data/")
images = mnist.train.images
labels = mnist.train.labels.astype("int")

vespa_feed = []
num_per_label = 10

for label in range(10):
    remaining = num_per_label
    for i,l in enumerate(labels):
        if l == label:
            image = images[i]
            id = label * num_per_label + num_per_label - remaining

            cells = []
            for d1, c in enumerate(image):
                cells.append({
                    "address": {"d0":"0", "d1":"%d" % d1},
                    "value": float(c)
                })
            vespa_feed.append({
                "put": "id:mnist:mnist::%d" % (id),
                "fields": {
                    "id": id,
                    "image": {
                        "cells": cells
                    }
                }
            })
            remaining -= 1
        if remaining == 0:
            break

with open("feed.json", "w") as f:
    json.dump(vespa_feed, f)



