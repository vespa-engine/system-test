# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class RankProperties < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_rankproperties
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")

    result = search("query=test&rankfeatures&ranking=rank1&ranking.properties.foo=40")
    assert(result.hit.size == 1)
    score = result.hit[0].field["relevancy"].to_f
    assert(score == 40.0)
    rf = result.hit[0].field["rankfeatures"]
    assert_features({"query(foo)" => 40}, rf)

    result = search("query=test&rankfeatures&ranking=rank1&ranking.properties.foo=50")
    assert(result.hit.size == 1)
    score = result.hit[0].field["relevancy"].to_f
    assert(score == 50.0)
    rf = result.hit[0].field["rankfeatures"]
    assert_features({"query(foo)" => 50}, rf)
  end


end
