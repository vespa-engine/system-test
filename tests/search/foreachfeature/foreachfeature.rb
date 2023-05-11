# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class ForeachFeature < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_foreach
    set_description("Test the foreach feature")
    deploy_app(SearchApp.new.sd(selfdir+"foreach.sd"))
    start
    feed_and_wait_for_docs("foreach", 2, :file => selfdir + "foreach.xml")

    run_foreach_test

    if !is_streaming
      # attribute fields are not registered in streaming search
      assert_foreach({"foreach(attributes,N,attribute(N),true,sum)"                                =>  12}, "dimensions", 0)
      assert_foreach({"foreach(attributes,N,foreach(attributes,M,attribute(M),true,sum),true,sum)" =>  24}, "dimensions", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),true,sum)"                                =>  48}, "dimensions", 1)
      assert_foreach({"foreach(attributes,N,foreach(attributes,M,attribute(M),true,sum),true,sum)" =>  96}, "dimensions", 1)

      assert_foreach({"foreach(attributes,N,attribute(N),true,average)" =>   6}, "operations", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),true,max)"     =>   8}, "operations", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),true,min)"     =>   4}, "operations", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),true,product)" =>  32}, "operations", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),true,count)"   =>   2}, "operations", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),true,average)" =>  24}, "operations", 1)
      assert_foreach({"foreach(attributes,N,attribute(N),true,max)"     =>  32}, "operations", 1)
      assert_foreach({"foreach(attributes,N,attribute(N),true,min)"     =>  16}, "operations", 1)
      assert_foreach({"foreach(attributes,N,attribute(N),true,product)" => 512}, "operations", 1)
      assert_foreach({"foreach(attributes,N,attribute(N),true,count)"   =>   2}, "operations", 1)

      assert_foreach({"foreach(attributes,N,attribute(N),\">7.9\",count)"  => 1}, "conditions", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),\"<16.1\",count)" => 2}, "conditions", 0)
      assert_foreach({"foreach(attributes,N,attribute(N),\">7.9\",count)"  => 2}, "conditions", 1)
      assert_foreach({"foreach(attributes,N,attribute(N),\"<16.1\",count)" => 1}, "conditions", 1)
    end
  end

  def run_foreach_test
    result = search_with_timeout(60, "query=a+b+c")
    assert_equal(13, result.hit[0].field["relevancy"].to_i) # 2*2+3*3
    assert_equal(5,  result.hit[1].field["relevancy"].to_i) # 1*1+2*2

    assert_foreach({"foreach(fields,N,fieldMatch(N).matches,true,sum)" =>   5}, "dimensions", 0)
    assert_foreach({"foreach(terms,N,term(N).weight,true,sum)"         => 600}, "dimensions", 0)
    assert_foreach({"foreach(fields,N,fieldMatch(N).matches,true,sum)" =>   3}, "dimensions", 1)
    assert_foreach({"foreach(terms,N,term(N).weight,true,sum)"         => 600}, "dimensions", 1)

    assert_foreach({"foreach(terms,N,term(N).weight,true,sum)" => 300}, "max-terms", 0)
    assert_foreach({"foreach(terms,N,term(N).weight,true,sum)" => 300}, "max-terms", 1)
  end

  def assert_foreach(expected, ranking, docid)
    query = "query=a!300+b!200+c&ranking=" + ranking
    result = search_with_timeout(60, query)
    assert_features(expected, result.hit[docid].field['summaryfeatures'], 1e-4)
  end


  def teardown
    stop
  end

end
