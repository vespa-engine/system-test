# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class QueryTermOrder < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_order
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.xml")

    assert_order
  end

  def assert_order
    assert_hitcount("query=test&parallel", 3)

    # least important term first
    result = search("query=a!100+b!200+c!300&parallel")
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf

    assert_features({"term(0).weight" =>  100}, json)
    assert_features({"term(1).weight" =>  200}, json)
    assert_features({"term(2).weight" =>  300}, json)

    # most important term first
    result = search("query=c!300+b!200+a!100&parallel")
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf

    assert_features({"term(0).weight" =>  300}, json)
    assert_features({"term(1).weight" =>  200}, json)
    assert_features({"term(2).weight" =>  100}, json)
  end

  def teardown
    stop
  end

end
