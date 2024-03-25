# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

  def teardown
    stop
  end

end
