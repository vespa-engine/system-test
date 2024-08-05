#!/bin/sh
# Copyright Vespa.ai. All rights reserved.

for file in *.actual; do
    cp $file ${file%.actual}
done
