#!/bin/bash
# Copyright Vespa.ai. All rights reserved.

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
