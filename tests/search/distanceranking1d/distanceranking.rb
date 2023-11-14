# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class DistanceRanking1D < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Test distance ranking")
    deploy_app(SearchApp.new.sd(selfdir+"local.sd"))
    start
  end

  def initialize(*args)
    super(*args)
  end

  def test_1d_distance_ranking
    feed_and_wait_for_docs("local", 10, :file => selfdir+"local.10.xml")

    # no ranking, so sort results by id
    assert_result("query=poi&hits=10", selfdir+"allhits.result.json", "id")
    assert_result("query=len:[-1180000%3B-1170000]", selfdir+"dist_cutoff.result.json", "id")
  end

  def teardown
    stop
  end

end
