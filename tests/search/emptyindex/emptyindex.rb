# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class EmptyIndex < IndexedSearchTest

  # with 2 columns and 1 document, one of the columns will get an empty index.

  def setup
    set_owner("aressem")
    deploy_app(singlenode_2cols_realtime(SEARCH_DATA+"music.sd"))
    start
  end

  def test_emptyindex
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.xml")

    puts "Query: Return the one doc"
    assert_result("query=concerto", selfdir + "emptyindex.result.json")
  end

  def teardown
    stop
  end

end
