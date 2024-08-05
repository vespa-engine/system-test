# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Post_Searcher < IndexedStreamingSearchTest

  def setup
    set_owner("bjorncs")
    set_description("Test that we can POST to a searcher")
    add_bundle(selfdir + "PostSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.example.PostSearcher"))
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").search_chain(search_chain))
    start
  end

  def test_twophase_searcher
    result = vespa.container.values.first.post_search("/search/?query=", "Hello world", 0, {'Content-Type' => 'text/plain'})
    assert(result.to_s =~ /Hello world/)
  end

  def teardown
    stop
  end

end
