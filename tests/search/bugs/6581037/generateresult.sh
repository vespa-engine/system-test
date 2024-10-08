#!/bin/bash
# Copyright Vespa.ai. All rights reserved.

total=$1
count=$2
echo '{'
echo '  "root":{'
echo '    "id":"toplevel",'
echo '    "fields":{'
echo '      "totalCount":'$total
echo '    },'
echo '    "children":['

read f
echo '      {'
echo '        "fields":{'
echo "          \"id\":0"
if [ "$f" != "" ]
then
  echo "         ,\"title\":\"$f\""
fi
echo '        }'

for ((i=1;$i<$count;i=$i+1))
do
  read f
  echo '      },{'
  echo '        "fields":{'
  echo "          \"id\":$i"
  if [ "$f" != "" ]
  then
    echo "         ,\"title\":\"$f\""
  fi
  echo '        }'
done

echo '      }'

echo '    ]'
echo '  }'
echo '}'
