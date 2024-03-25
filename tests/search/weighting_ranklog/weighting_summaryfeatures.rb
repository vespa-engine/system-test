# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class Weighting_Ranklog < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Rank using weighting of terms, also check summaryfeatures")
    deploy_app(SearchApp.new.sd(selfdir+"weight.sd"))
    start
  end

  def test_weighting_summaryfeatures
    feed_and_wait_for_docs("weight", 6, :file => selfdir+"weighting_ranklog.xml")

    puts "Query: no weighting"
    expected = {
        "term(0).weight" => 100,
        "term(1).weight" => 100
    }
    result = search('query=black+desc:black&type=all');
    assert_equal(1, result.hitcount)
    assert_features(expected, result.hit[0].field['summaryfeatures'])

    puts "Query: heavy weighting"
    expected = {
        "term(0).weight" => 10000,
        "term(1).weight" => 100
    }
    result = search('query=black\!10000+desc:black&type=all');
    assert_equal(1, result.hitcount)
    assert_features(expected, result.hit[0].field['summaryfeatures'])

  end

  def teardown
    stop
  end

end
