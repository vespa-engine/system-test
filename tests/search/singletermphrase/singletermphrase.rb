# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SingleTermPhrase < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Check single term phrases are handled OK")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_singletermphrase
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.json")

    puts "Query: Querying, old problem query"
    assert_result("query=CET-4%E6%88%90%E7%BB%A9&tracelevel=5&language=zh-hans&format=xml",
                  selfdir+"first.result")

    puts "Query: Querying, invalid UTF-8"
    assert_result("query=%C3%83%C2%98%C3%82%C2%B5%C3%83%C2%99%C3%82%C2%88%C3%83%C2%98%C3%82%C2%B1&tracelevel=5&language=zh-hans&format=xml",
                  selfdir+"second.result")
  end

  def teardown
    stop
  end

end
