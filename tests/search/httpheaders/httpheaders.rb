# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class HttpHeaders < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
  end

  def test_custom_http_headers
    clear_bundles()
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.HttpHeadersSearcher")
    search_chain = SearchChain.new.add(Searcher.new("com.yahoo.vespatest.HttpHeadersSearcher"))
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").search_chain(search_chain))
    start

    headername = "X-Vespa-System-Test"
    headervalue = "Vespa HTTP header test"
    feed_and_wait_for_docs("music", 10, { :file => SEARCH_DATA+"music.10.json" })
    result = search("/?query=blues", 0, { headername => headervalue })
    assert_equal(10, result.hit.size)
    assert_equal(headervalue, result.header(headername).first)
  end

  def teardown
    stop
  end

end
