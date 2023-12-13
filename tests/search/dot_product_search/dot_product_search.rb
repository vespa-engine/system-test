# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class DotProductSearch < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    set_description("test dot product query term searching")
  end

  def teardown
    stop
  end

  def build_tokens(vector)
    tokens = ""
    vector.each_with_index do |(key,value), index|
      tokens << "," if index > 0
      tokens << "#{key}:#{value}"
    end
    tokens
  end

  def build_query(model)
    query = "/search/?"
    model.each_with_index do |vector, index|
      query << "&" if index > 0
      query << "dp#{index+1}.field=features&dp#{index+1}.tokens=%7B#{build_tokens(vector)}%7D"
    end
    query
  end

  def extract_subscores(jsf, count)
    sub_scores = []
    count.times do |i|
      sub_scores << jsf["itemRawScore(dp#{i+1})"]
    end
    sub_scores
  end

  # Verify that the given query model produces the expected results.
  #
  # The query model is a list of sparse vectors that will be passed to
  # the test searcher. The searcher will make a dot product query item
  # for each vector and combine them with AND. The expected result
  # contains a list with a list for each expected hit. The inner list
  # contains the raw score for each of the vectors in the query
  # model. The sum of the raw score across dot products is used for
  # ranking, and thus the expected results must also be sorted by this
  # criteria.
  def verify_result(expect, model)
    puts "running query: #{build_query(model)}"
    result = search(build_query(model))
    assert_equal(expect.size, result.hit.size)
    expect.each_with_index do |expected_sub_scores,i|
      jsf = result.hit[i].field['summaryfeatures']
      sub_scores = extract_subscores(jsf, model.size)
      assert_equal(expected_sub_scores, sub_scores,
                   "subscores differ for hit #{i}: #{expected_sub_scores} != #{sub_scores}")
    end
  end

  def test_dot_product
    add_bundle(selfdir + "DotProductTestSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.test.DotProductTestSearcher"))
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").search_chain(search_chain))
    start
    feed(:file => selfdir + "docs.xml")
    verify_result([[500],[400],[300],[200],[100]], [{"test"=>10}])
    verify_result([[5000],[4000],[3000],[2000],[1000]], [{"test"=>100}])
    verify_result([[(10*30), (1 * 9)],               # doc 3
                   [(10*20 + 5*6), (5*4 + 5*6)],     # doc 2
                   [(10*10), (10*1 + 10*2 + 10*3)]], # doc 1
                  [{"test"=>10,"baz2"=>5},{"foo1"=>10,"bar1"=>10,"baz1"=>10,"bar2"=>5,"baz2"=>5,"baz3"=>1}])
  end

  def test_negative_weights
    add_bundle(selfdir + "DotProductTestSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.test.DotProductTestSearcher"))
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").search_chain(search_chain))
    start
    feed(:file => selfdir + "docs.xml")
    verify_result([[-100]], [{"bad1"=>10}])
    verify_result([[-100],[-200],[-300],[-400],[-500]], [{"test"=>-10}])
    verify_result([[100]], [{"bad1"=>-10}])
  end

end
