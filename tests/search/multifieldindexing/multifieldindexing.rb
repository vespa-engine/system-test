# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MultifieldIndexing < IndexedSearchTest

  def setup
    set_owner("musum")
    set_description("Test indexing multiple attributes with different parameters (stemming etc) into a single index")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_multifield_indexing
    feed_and_wait_for_docs("music", 8, :file => SEARCH_DATA+"testnounstemming.8.xml")

    puts "QUERY: test that an index has been created"
    assert_hitcount("query=title:towers", 2)
  end

  def teardown
    stop
  end

end
