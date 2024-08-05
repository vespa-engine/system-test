# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class EmptyIndex < IndexedStreamingSearchTest

  # with 2 columns and 1 document, one of the columns will get an empty index.

  def setup
    set_owner("aressem")
    deploy_app(singlenode_2cols_realtime(SEARCH_DATA+"music.sd"))
    start
  end

  def test_emptyindex
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.json")

    puts "Query: Return the one doc"
    assert_result("query=concerto", selfdir + "emptyindex.result.json", nil, ["surl"])
  end

  def teardown
    stop
  end

end
