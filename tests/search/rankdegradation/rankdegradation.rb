# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'


class RankDegradation < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_degradation
    set_description("Test rank degradation in parallel query evaluation")
    deploy_app(SearchApp.new.sd(selfdir + "rankd.sd"))
    start
    feed_and_wait_for_docs("rankd", 4, :file => selfdir + "rankd.json")

    assert_degradation_exact(40, 0, "default")
    assert_degradation_exact(30, 1, "default")
    assert_degradation_exact(20, 2, "default")
    assert_degradation_exact(10, 3, "default")

    assert_degradation_exact(40, 0, "drop-limit", 2)
    assert_degradation_exact(30, 1, "drop-limit", 2)

    run_nan_test
  end

  def run_nan_test
    r = search("query=f1:10&ranking=nan")
    assert_equal("-Infinity", r.hit[0].field["relevancy"])
    sf = r.hit[0].field['summaryfeatures']
    puts "summaryfeatures: #{sf.to_a.join(":")}"
    assert_equal(nil, sf.fetch("firstPhase"))
  end

  def get_query(rank_profile)
    return "query=f1:%3E0&ranking=#{rank_profile}"
  end

  def get_result(rank_profile, hitcount = 4)
    assert_hitcount(get_query(rank_profile), hitcount)
    return search(get_query(rank_profile))
  end

  def assert_degradation_exact(rank, doc, rank_profile, hitcount = 4)
    result = get_result(rank_profile, hitcount)
    assert_equal(rank, result.hit[doc].field["relevancy"].to_i)
  end

  def assert_degradation_atleast(rank, doc, rank_profile, hitcount = 4)
    result = get_result(rank_profile, hitcount)
    relevancy = result.hit[doc].field["relevancy"].to_i
    assert(relevancy >= rank, "Expected relevancy to be >= than #{rank}, but was #{relevancy}")
  end

  def teardown
    stop
  end

end
