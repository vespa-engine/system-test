# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class TwoPhase_Searcher < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Test that we can plug in twophase QRS searchers")
    add_bundle(selfdir + "TwoPhaseTestSearcher.java")
    deploy_app(SearchApp.new.sd(SEARCH + "data/music.sd").
                      search_chain(SearchChain.new.add(
                        Searcher.new("com.yahoo.example.TwoPhaseTestSearcher",
                                     "transformedQuery", "blendedResult"))))
    start
  end

  def test_twophase_searcher
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.json")

    puts "Query: Search for frank"
    assert_result("/search/?query=frank&tracelevel=1", selfdir+"expect.result.json")
  end

  def teardown
    stop
  end

end
