# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class PacketCompressLimit < IndexedSearchTest

  def setup
    set_owner("bjorncs")
    deploy_app(SearchApp.new.  sd("#{SEARCH_DATA}/music.sd"))
    start
  end

  def test_packet_compress_limit
    feed_and_wait_for_docs("music", 10, :file => "#{SEARCH_DATA}/music.10.xml");
    assert_result("query=sddocname:music", "#{SEARCH_DATA}/music.10.result.json",
                  "title", ["title", "surl", "mid"])
  end

  def teardown
    stop
  end

end
