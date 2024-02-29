#!/bin/bash
# If there is no xml header in the given file it will prepend a header,
# and append a footer to make it legal xml feed.

head -1 $1 | grep "xml version"
valid_xml=$?
if [ $valid_xml -ne 0 ]; then
    echo '<?xml version="1.0" encoding="utf-8"?>'
    echo "<vespafeed>"
    cat $1 
    echo "</vespafeed>"
else
    cat $1
fi
