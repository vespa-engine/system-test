#!/bin/bash
# If there is no xml header in the given file it will prepend a header,
# and append a footer to make it legal xml feed.

valid_xml=`head -1 $1 | grep "xml version" | wc -l`
if [ $valid_xml -ne 1 ]; then
    echo '<?xml version="1.0" encoding="utf-8"?>'
    valid_vespafeed=`cat $1 | grep "vespafeed" | wc -l`
    if [ $valid_vespafeed -ne 2 ]; then
        echo "<vespafeed>"
        cat $1
        echo "</vespafeed>"
    else
        cat $1
    fi
else
    cat $1
fi
