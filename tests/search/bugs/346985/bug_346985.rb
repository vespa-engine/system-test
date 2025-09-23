# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class Bug_346985 < IndexedStreamingSearchTest

  # Description: Test proximitygap. It is in most cases not desirable to get
  #              proximity score from terms matching in separate consecutive fields.
  # Component:   Search and Config
  # Feature:     Ranking

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir + "proximitygap.sd"))
    start
  end

  def test_proximity_gap
    feed_and_wait_for_docs("proximitygap", 2, :file => selfdir+"proximitygap.2.json")

    assert_result("query=bar+fuzz", selfdir + "proximitygap.default.result.json", nil, "id")

    assert_result("query=bar+fuzz&ranking=only-proximity", selfdir + "proximitygap.onlyproximity.result.json", nil, "id")
  end


end
