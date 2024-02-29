#!/bin/bash
# Will convert a old style xml feed to json.
# vespa must be running and the searchdefinition deployed.

base=$(basename $1 ".xml")
wrap-xml-feed.sh $1 | vespa-feed-perf -o "$base.json"
