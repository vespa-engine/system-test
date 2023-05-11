# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class DocumentFeatures < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_attribute
    set_description("Test the attribute feature")
    deploy_app(SearchApp.new.sd(selfdir+"attribute.sd"))
    start
    feed_and_wait_for_docs("attribute", 1, :file => selfdir + "attribute.xml")

    result = search("query=idx:a&streaming.userid=1")
    puts "summaryfeatures: '#{result.hit[0].field["summaryfeatures"]}'"

    # integer attributes
    assert_attribute("attribute(si)",   10)
    assert_attribute("attribute(ai,0)", 10)
    assert_attribute("attribute(ai,1)", 20)
    assert_attribute("attribute(ai,2)", 0)
    assert_attribute("attribute(wi,10).weight",   100)
    assert_attribute("attribute(wi,10).contains", 1)
    assert_attribute("attribute(wi,20).weight",   0)
    assert_attribute("attribute(wi,20).contains", 0)

    # float attributes
    assert_attribute("attribute(sf)",   10.5)
    assert_attribute("attribute(af,0)", 10.5)
    assert_attribute("attribute(af,1)", 20.5)
    assert_attribute("attribute(af,2)", 0)

    # string attributes
    assert_attribute("attribute(ss)",   1.7409184128169565e-43)   # hash of 'first'
    assert_attribute("attribute(as,0)", 1.7409184128169565e-43)   # hash of 'first'
    assert_attribute("attribute(as,1)", 8.379872018783626e-76) # hash of 'second'
    assert_attribute("attribute(as,2)", 0)
    assert_attribute("attribute(ws,first).weight",   100)
    assert_attribute("attribute(ws,first).contains", 1)
    assert_attribute("attribute(ws,second).weight",   0)
    assert_attribute("attribute(ws,second).contains", 0)

    # partial updates on array fields
    feed(:file => selfdir + "attribute.upd.xml")
    assert_attribute("attribute(ai,2)", 40)
    assert_attribute("attribute(af,2)", 40.5)
    assert_attribute("attribute(as,2)", -9.774744375149687e-197) # hash of 'fourth'
    assert_attribute("attribute(ai,3)", 30)
    assert_attribute("attribute(af,3)", 30.5)
    assert_attribute("attribute(as,3)", -1.7865425069493262e+45) # hash of 'third'
  end

  def assert_attribute(feature, score)
    result = search("query=idx:a&streaming.userid=1")
    assert_features({feature => score}, result.hit[0].field['summaryfeatures'])
  end

  def teardown
    stop
  end

end
