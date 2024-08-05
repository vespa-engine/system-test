#!/bin/bash
# Copyright Vespa.ai. All rights reserved.

cnt=0
"$@"
res=$?
while [ $res == 0 ] ; do
    cnt=$(($cnt + 1))
    echo "PASS COUNT: $cnt"
    "$@"
    res=$?
done
echo "operation failed after $cnt passes"
