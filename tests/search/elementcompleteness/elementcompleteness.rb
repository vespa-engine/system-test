# Copyright Vespa.ai. All rights reserved.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class ElementCompleteness < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_elementcompleteness
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22test%22%20OR%20foobar%20contains%20%22a%22%20OR%20foobar%20contains%20%22b%22%20OR%20foobar%20contains%20%22c%22%20OR%20foobar%20contains%20%22d%22%29%3B&type=yql")
    assert(result.hit.size == 1)
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf
    assert_features({"elementCompleteness(foo).completeness" => 0.875 }, json)
    assert_features({"elementCompleteness(foo).fieldCompleteness" => 1.0 }, json)
    assert_features({"elementCompleteness(foo).queryCompleteness" => 0.75 }, json)
    assert_features({"elementCompleteness(foo).elementWeight" => 1 }, json)

    assert_features({"elementCompleteness(bar).completeness" => 0.875 }, json)
    assert_features({"elementCompleteness(bar).fieldCompleteness" => 1.0 }, json)
    assert_features({"elementCompleteness(bar).queryCompleteness" => 0.75 }, json)
    assert_features({"elementCompleteness(bar).elementWeight" => 19 }, json)

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22test%22%20OR%20productid%20contains%20%22a%20b%22%20OR%20productid%20contains%20%22a%20b%20c%20x%22%29%3B&type=yql")
    assert(result.hit.size == 1)
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf
    assert_features({"elementCompleteness(productid).completeness" => 0.75 }, json)
    assert_features({"elementCompleteness(productid).fieldCompleteness" => 1.0 }, json)
    assert_features({"elementCompleteness(productid).queryCompleteness" => 0.5 }, json)
    assert_features({"elementCompleteness(productid).elementWeight" => 18 }, json)

    # NB: it is bad that these are all 0
    result = search("select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22test%22%20OR%20hash%20contains%20%22a%20b%22%20OR%20hash%20contains%20%22a%20b%20c%20x%22%29%3B&type=yql")
    assert(result.hit.size == 1)
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf
    assert_features({"elementCompleteness(hash).elementWeight" => 18 }, json)
    assert_features({"elementCompleteness(hash).completeness" => 0.75 }, json)
    assert_features({"elementCompleteness(hash).fieldCompleteness" => 1.0 }, json)
    assert_features({"elementCompleteness(hash).queryCompleteness" => 0.5 }, json)

  end

  def teardown
    stop
  end

end
