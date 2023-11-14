# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class TensorDotProductTest < IndexedStreamingSearchTest

  def setup
    set_owner("toregge")
  end

  def check_result(result, r1, r2)
    assert_equal(2, result.hit.size)
    assert_equal(1, result.hit[0].field["id"].to_i)
    assert_equal(r1, result.hit[0].field["relevancy"].to_f)
    assert_equal(0, result.hit[1].field["id"].to_i)
    assert_equal(r2, result.hit[1].field["relevancy"].to_f)
  end

  def test_tensor_dot_product
    set_description("Test basic tensor dot product in ranking expression")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "docs.json")

    check_result(search(get_query(13,17)), 252.0, 77.0)
    check_result(search(get_queryf(13,17)), 252.0, 77.0)

    check_result(search(get_query(13,18)), 263.0, 80.0)
    check_result(search(get_queryf(13,18)), 263.0, 80.0)

    check_result(search(get_query(14,17)), 257.0, 79.0)
    check_result(search(get_queryf(14,17)), 257.0, 79.0)
  end

  def get_query(x_0, x_1)
    "query=sddocname:test&ranking.features.query(qvector)={{x:0}:#{x_0},{x:1}:#{x_1}}"
  end

  def get_queryf(x_0, x_1)
    "query=sddocname:test&ranking=usefloat&ranking.features.query(qvectorf)={{x:0}:#{x_0},{x:1}:#{x_1}}"
  end

  def teardown
    stop
  end

end
