#!/usr/bin/env python3
# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import sys
import re
import time

from urllib.request import urlopen

# Scrapes a url and returns a string with the document content.
def httpget(url):
    filehandle = urlopen(url)
    doctext = filehandle.read()
    filehandle.close()
    print(doctext.decode('utf-8'))
    
if __name__ == "__main__":
    if len(sys.argv) != 2:
       print("usage: python httpclient.py <URL>")
       sys.exit(0)
    httpget(sys.argv[1])

  
    	

