# Copyright Vespa.ai. All rights reserved.
require 'erb'

# Simple script which takes in newline-separated raw queries on stdin (or a file)
# and outputs a fbench-formatted HTTP GET query per line. Only `yql` and `query`
# parameters are populated; other parameters should be appended explicitly by tests.

def uri_enc(str)
  ERB::Util.url_encode(str)
end

yql = uri_enc('select * from wikimedia where userQuery()')

ARGF.each_line do |line|
  puts "/search/?yql=#{yql}&query=#{uri_enc(line)}"
end
