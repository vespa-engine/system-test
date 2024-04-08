# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class FeatureOverride < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_featureoverride
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "doc.json")
    run_featureoverride_test
  end

  def run_featureoverride_test
    assert_featureoverride(1,  5,   3,  true,  1, "query=test&rankfeature.value(2)=5")
    assert_featureoverride(5,  2,   3,  true,  1, "query=test&rankfeature.value(1)=5")
    assert_featureoverride(10, 2,   3,  true,  1, "query=test&rankfeature.value(1)=10")
    assert_featureoverride(1,  2,   50, false, 2, "query=both&rankfeature.value(3)=50")
    assert_featureoverride(1,  50,  3,  false, 2, "query=both&rankfeature.value(2)=50")
    assert_featureoverride(1,  100, 3,  false, 2, "query=both&rankfeature.value(2)=100")
    assert_featureoverride(10, 20,  30, true,  1, \
    "query=test&rankfeature.value(1)=10&rankfeature.value(2)=20&rankfeature.value(3)=30")
  end

  def assert_featureoverride(v1, v2, v3, cached, hits, query)
    result = search(query)
    assert(result.hit.size == hits)
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf
    assert_features({"value(1)" => v1}, json)
    assert_features({"value(2)" => v2}, json)
    assert_features({"value(3)" => v3}, json)
    assert_features({"attribute(attr)" => 200}, json)
  end

  def teardown
    stop
  end

end
