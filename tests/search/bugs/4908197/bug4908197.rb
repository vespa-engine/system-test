# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class Bug4908197 < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Test bug 4908197, JSON encoding issues")
  end

  def test_bug4908197
    deploy_app(SearchApp.new.sd(selfdir+"strarr.sd"))
    start
    feed(:file => selfdir+"feed.json")
    assert_result("query=foo", selfdir+"result.json")
  end


end
