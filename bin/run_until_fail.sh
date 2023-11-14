#!/bin/bash
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
