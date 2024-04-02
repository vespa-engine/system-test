#!/bin/bash
# Will convert an old-style xml feed to json.
# vespa must be running and schema(s) deployed.

base=$(basename $1 ".xml")
dir=$(dirname $1)
wrap-xml-feed.sh $1 | vespa-feed-perf -o "$dir/$base.json"
echo "" >> "$dir/$base.json"
