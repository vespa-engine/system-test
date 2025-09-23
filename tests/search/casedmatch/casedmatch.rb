# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class CasedMatch < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
  end

  def test_cased_match
    deploy_app(SearchApp.new.sd(selfdir+"casedmatch.sd"))
    start

    feed_and_wait_for_docs("casedmatch", 2, :file => selfdir+"feed.json")

    assert_hitcount("query=field1:Foo", 2)
    assert_hitcount("query=field1:Bar", 1)
    assert_hitcount("query=field1:Baz", 0)
    assert_hitcount("query=field1:foo", 0)
    assert_hitcount("query=field1:bar", 1)
    assert_hitcount("query=field1:baz", 2)

    assert_hitcount("query=field2:Foo", 1)
    assert_hitcount("query=field2:foo", 0)
    assert_hitcount("query=field2:Bar", 0)
    assert_hitcount("query=field2:bar", 1)
  end


end
