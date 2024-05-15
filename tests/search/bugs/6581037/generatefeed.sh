#!/bin/bash
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

i=0
echo "["
while read f
do
  if [ "$i" != 0 ]; then
      echo ","
  fi
  echo " { \"put\": \"id:test:test::$1-$i\","
  echo "  \"fields\": { \"id\": \"$i\", \"title\": \"$f\", \"lang\": \"$1\" }"
  echo " }"
  ((i=$i + 1))
done
echo "]"
