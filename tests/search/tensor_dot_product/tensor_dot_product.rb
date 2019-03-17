# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class TensorDotProductTest < IndexedSearchTest

  def setup
    set_owner("toregge")
  end

  def test_tensor_dot_product
    set_description("Test basic tensor dot product in ranking expression")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
               search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "docs.json", :json => true)

    result = search(get_query(13,17))
    assert_equal(2, result.hit.size)
    assert_equal(1, result.hit[0].field["id"].to_i)
    assert_equal(252.0, result.hit[0].field["relevancy"].to_f)
    assert_equal(0, result.hit[1].field["id"].to_i)
    assert_equal(77.0, result.hit[1].field["relevancy"].to_f)

    result = search(get_query(13,18))
    assert_equal(2, result.hit.size)
    assert_equal(1, result.hit[0].field["id"].to_i)
    assert_equal(263.0, result.hit[0].field["relevancy"].to_f)
    assert_equal(0, result.hit[1].field["id"].to_i)
    assert_equal(80.0, result.hit[1].field["relevancy"].to_f)

    result = search(get_query(14,17))
    assert_equal(2, result.hit.size)
    assert_equal(1, result.hit[0].field["id"].to_i)
    assert_equal(257.0, result.hit[0].field["relevancy"].to_f)
    assert_equal(0, result.hit[1].field["id"].to_i)
    assert_equal(79.0, result.hit[1].field["relevancy"].to_f)
  end

  def get_query(x_0, x_1)
    "query=sddocname:test&ranking.features.query(qvector)={{x:0}:#{x_0},{x:1}:#{x_1}}"
  end

  def teardown
    stop
  end

end
