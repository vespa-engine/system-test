# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ExactMatch < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
  end

  def test_exact_match
    deploy_app(SearchApp.new.sd(selfdir+"exactmatch.sd"))
    start

    if is_streaming
      s = "&streaming.selection=true"
    else
      s = ""
    end
    feed_and_wait_for_docs("exactmatch"+s, 1, :file => selfdir+"feed.xml")

    exactmatch_common(s)
    if is_streaming
      exactmatch_streaming(s)
    else
      exactmatch_indexed(s)
    end
  end

  def exactmatch_common(s)
    assert_hitcount("query=field1:motors"+s, 1)
    assert_hitcount("query=field2:motor"+s, 0)
    assert_hitcount("query=field2:motors"+s, 1)
    assert_hitcount("query=field3:Alice spends 400 000$ on a flashy red car.*!*"+s, 1)
    assert_hitcount("query=field4:Alice spends 400 000$ on a flashy red car.//END//"+s, 1)
    assert_hitcount("query=field5:New York"+s, 0)
    assert_hitcount("query=field5:new york"+s, 0)

    assert_hitcount("query=field10:'n sync"+s, 0)
    assert_hitcount("query=field9:%22new york%22"+s, 1)
    assert_hitcount("query=field10:%22new york%22"+s, 1)
    assert_hitcount("query=field10:%22wham!%22"+s, 1)
    assert_hitcount("query=field10:%22'n sync%22"+s, 1)
    assert_hitcount("query=field10:a*teens"+s, 1)
    assert_hitcount("query=field10:a"+s, 0)
    assert_hitcount("query=field10:teens"+s, 0)
    assert_hitcount("query=field10:wham"+s, 0)
    assert_hitcount("query=field10:new"+s, 0)
    assert_hitcount("query=field10:york"+s, 0)
    assert_hitcount("query=field10:%22wham!%22!"+s, 1)
    assert_hitcount("query=field10:a*teens!"+s, 1)
  end

  def exactmatch_indexed(s)
    assert_hitcount("query=field1:motor", 1)  # Streaming does not use indexingdocproc so no stemming.
    assert_hitcount("query=field6_i:New York*!*"+s, 1)
    assert_hitcount("query=field6_i:new york*!*"+s, 1)
    assert_hitcount("query=field7_i:New York"+s, 0)
    assert_hitcount("query=field7_i:new york"+s, 0)
    assert_hitcount("query=field8_i:New York*!*"+s, 1)
    assert_hitcount("query=field8_i:new york*!*"+s, 1)
    assert_hitcount("query=field10:'n*", 1)   # ails since it is not whole field match. still token based in streaming search.
    assert_hitcount("query=field10:wh*", 1)
  end

  def exactmatch_streaming(s)
    assert_hitcount("query=field1:motor"+s, 0)  # Streaming does not use indexingdocproc so no stemming.
    assert_hitcount("query=field6:New York*!*"+s, 1)
    assert_hitcount("query=field6:new york*!*"+s, 1)
    assert_hitcount("query=field7:New York"+s, 0)
    assert_hitcount("query=field7:new york"+s, 0)
    assert_hitcount("query=field8:New York*!*"+s, 1)
    assert_hitcount("query=field8:new york*!*"+s, 1)
    assert_hitcount("query=field10:'n*"+s, 1)
    assert_hitcount("query=field10:wh*"+s, 1)
  end

  def teardown
    stop
  end

end
