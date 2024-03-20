# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class LargeSummary < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_largesummary
    feed_and_wait_for_docs("music", 1, :file => selfdir+"largesummary.1.json", :timeout => 240)
    assert_hitcount("query=sddocname:music", 1)
    result = search("query=sddocname:music", 0)
    assert(result.hit[0].field["song"].to_s.length > 65536, "Field length is #{result.hit[0].field["song"].to_s.length}, expected more than 65536")

  end

  def teardown
    stop
  end

end
