# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class ArrayIndexing < IndexedStreamingSearchTest

  def setup
    set_description("Tests indexing of arrays and weighted sets, and how they are presented in summaries")
    set_owner("bratseth")
  end

  def test_arrayindexing
    deploy_app(SearchApp.new.sd(selfdir+"arrayindexing.sd"))
    start
    feed_and_wait_for_docs("arrayindexing", 1, :file => selfdir+"feed.json")
    assert_hitcount("query=misunderstood", 1)
    assert_hitcount("query=songtitle:misunderstood", 1)
    assert_hitcount("query=say you miss me", 1)
    assert_hitcount("query=songtitle:%22say you miss me%22", 1)
    assert_hitcount("query=far far away monday", 1)

    # Should not match phrases accross consequtive array items
    assert_hitcount("query=%22far far away monday%22", 0)
    assert_hitcount("query=%22blackend and%22", 0)

    assert_hitcount("query=blackend", 1)
    assert_hitcount("query=justice", 1)
    assert_hitcount("query=ride", 1)

    assert_result("query=sddocname:arrayindexing", selfdir + "result.json", nil, ["songtitles", "weightedtitles"])
  end


end
