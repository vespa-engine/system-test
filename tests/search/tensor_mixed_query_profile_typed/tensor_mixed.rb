# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class MixedTensorWithQueryProfileTest < IndexedStreamingSearchTest

  def setup
    set_owner("lesters")
  end

  def test_basic_mixed_tensor
    set_description("Same as tensor_mixed but using a query profile for typing instead of inputs")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
               search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")

    result = search(get_query("{{x:x1,y:0}:1}"))
    assert_equal(3, result.hit.size)
    assert_equal(3, result.hit[0].field["id"].to_i)
    assert_equal(31.0, result.hit[0].field["relevancy"].to_f)
    assert_equal(2, result.hit[1].field["id"].to_i)
    assert_equal(21.0, result.hit[1].field["relevancy"].to_f)
    assert_equal(1, result.hit[2].field["id"].to_i)
    assert_equal(11.0, result.hit[2].field["relevancy"].to_f)

    result = search(get_query("{{x:x1,y:1}:1,{x:x2,y:2}:1}"))
    assert_equal(3, result.hit.size)
    assert_equal(3, result.hit[0].field["id"].to_i)
    assert_equal(280.0, result.hit[0].field["relevancy"].to_f)
    assert_equal(2, result.hit[1].field["id"].to_i)
    assert_equal(200.0, result.hit[1].field["relevancy"].to_f)
    assert_equal(1, result.hit[2].field["id"].to_i)
    assert_equal(120.0, result.hit[2].field["relevancy"].to_f)

  end

  def get_query(tensor)
    "query=sddocname:test&ranking.features.query(tensor)=#{tensor}"
  end

  def teardown
    stop
  end

end
