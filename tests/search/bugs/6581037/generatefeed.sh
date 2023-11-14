#!/bin/bash
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

i=0
while read f
do
  echo "<document documenttype=\"test\" documentid=\"id:test:test::$1-$i\">"
  echo "  <id>$i</id>"
  echo "  <title>$f</title>"
  echo "  <lang>$1</lang>"
  echo "</document>"
  ((i=$i + 1))
done
