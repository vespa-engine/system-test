# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class FilterIndexesLogical < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test filter indexes using inheritance in schema")
    deploy_app(SearchApp.new.sd(selfdir+"father.sd").sd(selfdir+"music.sd"))
    start
    feed_and_wait_for_docs("music", 2, :file => selfdir+"../musicdata.json")
  end

  def test_filterindexes
    result1 = search("query=artist:Bob");
    result2 = search("query=year:1997");
    result3 = search("query=Bob");
    result4 = search("query=anno:1997");
    assert_not_equal(0.0, result1.hit[0].field["relevancy"].to_f);
    assert_equal(0.0, result2.hit[0].field["relevancy"].to_f);
    assert_not_equal(0.0, result3.hit[0].field["relevancy"].to_f);
    assert_equal(0.0, result4.hit[0].field["relevancy"].to_f);
  end

  def teardown
    stop
  end

end
