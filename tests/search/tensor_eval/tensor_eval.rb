# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class TensorEvalTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_tensor_evaluation
    set_description("Test basic tensor evaluation in ranking expression")
    add_bundle(selfdir + "TensorInQuerySearcher.java")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
               search_dir(selfdir + "search").
               search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.TensorInQuerySearcher"))))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")

    barbie_id = 0
    heman_id  = 1
    tv_id     = 2

    kid_f_result = search("query=sddocname:test&rankproperty.age={kid:1}&rankproperty.sex={f:1}")
    assert_equal(3, kid_f_result.hit.size)
    assert_equal(barbie_id, kid_f_result.hit[0].field["id"].to_i)
    assert_equal(100.0, kid_f_result.hit[0].field["relevancy"].to_f)

    kid_m_result = search("query=sddocname:test&rankproperty.age={kid:1}&rankproperty.sex={m:1}")
    assert_equal(3, kid_m_result.hit.size)
    assert_equal(heman_id, kid_m_result.hit[0].field["id"].to_i)
    assert_equal(80.0, kid_m_result.hit[0].field["relevancy"].to_f)

    adult_f_result = search("query=sddocname:test&rankproperty.age={adult:1}&rankproperty.sex={f:1}")
    assert_equal(3, adult_f_result.hit.size)
    assert_equal(tv_id, adult_f_result.hit[0].field["id"].to_i)
    assert_equal(40.0, adult_f_result.hit[0].field["relevancy"].to_f)

    adult_m_result = search("query=sddocname:test&rankproperty.age={adult:1}&rankproperty.sex={m:1}")
    assert_equal(3, adult_m_result.hit.size)
    assert_equal(tv_id, adult_m_result.hit[0].field["id"].to_i)
    assert_equal(50.0, adult_m_result.hit[0].field["relevancy"].to_f)

    kid_f_result = search("query=sddocname:test&test.age=kid&test.sex=f&ranking=tensor")
    assert_equal(3, kid_f_result.hit.size)
    assert_equal(barbie_id, kid_f_result.hit[0].field["id"].to_i)
    assert_equal(200.0, kid_f_result.hit[0].field["relevancy"].to_f)

    kid_m_result = search("query=sddocname:test&test.age=kid&test.sex=m&ranking=tensor")
    assert_equal(3, kid_m_result.hit.size)
    assert_equal(heman_id, kid_m_result.hit[0].field["id"].to_i)
    assert_equal(160.0, kid_m_result.hit[0].field["relevancy"].to_f)

    adult_f_result = search("query=sddocname:test&test.age=adult&test.sex=f&ranking=tensor")
    assert_equal(3, adult_f_result.hit.size)
    assert_equal(tv_id, adult_f_result.hit[0].field["id"].to_i)
    assert_equal(80.0, adult_f_result.hit[0].field["relevancy"].to_f)

    adult_m_result = search("query=sddocname:test&test.age=adult&test.sex=m&ranking=tensor")
    assert_equal(3, adult_m_result.hit.size)
    assert_equal(tv_id, adult_m_result.hit[0].field["id"].to_i)
    assert_equal(100.0, adult_m_result.hit[0].field["relevancy"].to_f)
  end

  def teardown
    stop
  end

end
