# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ExactMatch < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
  end

  def test_exact_match
    deploy_app(SearchApp.new.sd(selfdir+"exactmatch.sd"))
    start

    feed_and_wait_for_docs("exactmatch", 2, :file => selfdir+"feed.xml")

    exactmatch_common
    exactmatch_no_accent_removal
    if is_streaming
      exactmatch_streaming
    else
      exactmatch_indexed
    end
  end

  def exactmatch_common
    assert_hitcount("query=field1:motors", 1)
    assert_hitcount("query=field2:motor", 0)
    assert_hitcount("query=field2:motors", 1)
    assert_hitcount("query=field3:Alice spends 400 000$ on a flashy red car.*!*", 1)
    assert_hitcount("query=field4:Alice spends 400 000$ on a flashy red car.//END//", 1)
    assert_hitcount("query=field5:New York", 0)
    assert_hitcount("query=field5:new york", 0)

    assert_hitcount("query=field10:'n sync", 0)
    assert_hitcount("query=field9:%22new york%22", 1)
    assert_hitcount("query=field10:%22new york%22", 1)
    assert_hitcount("query=field10:%22wham!%22", 1)
    assert_hitcount("query=field10:%22'n sync%22", 1)
    assert_hitcount("query=field10:a*teens", 1)
    assert_hitcount("query=field10:a", 0)
    assert_hitcount("query=field10:teens", 0)
    assert_hitcount("query=field10:wham", 0)
    assert_hitcount("query=field10:new", 0)
    assert_hitcount("query=field10:york", 0)
    assert_hitcount("query=field10:%22wham!%22!", 1)
    assert_hitcount("query=field10:a*teens!", 1)
  end

  def exactmatch_no_accent_removal
    assert_hitcount("query=field1:Håland", 1)
    assert_hitcount("query=field1:håland", 1)
    assert_hitcount("query=field1:Haland", 1)
    assert_hitcount("query=field1:haland", 1)
    assert_hitcount("query=field2:Håland", 1)
    assert_hitcount("query=field2:håland", 1)
    assert_hitcount("query=field2:Haland", 0)
    assert_hitcount("query=field2:haland", 0)
  end

  def exactmatch_indexed
    assert_hitcount("query=field1:motor", 1)  # Streaming does not use indexingdocproc so no stemming.
    assert_hitcount("query=field6_i:New York*!*", 1)
    assert_hitcount("query=field6_i:new york*!*", 1)
    assert_hitcount("query=field7_i:New York", 0)
    assert_hitcount("query=field7_i:new york", 0)
    assert_hitcount("query=field8_i:New York*!*", 1)
    assert_hitcount("query=field8_i:new york*!*", 1)
    assert_hitcount("query=field10:'n*", 1)   # ails since it is not whole field match. still token based in streaming search.
    assert_hitcount("query=field10:wh*", 1)
  end

  def exactmatch_streaming
    assert_hitcount("query=field1:motor", 0)  # Streaming does not use indexingdocproc so no stemming.
    assert_hitcount("query=field6:New York*!*", 1)
    assert_hitcount("query=field6:new york*!*", 1)
    assert_hitcount("query=field7:New York", 0)
    assert_hitcount("query=field7:new york", 0)
    assert_hitcount("query=field8:New York*!*", 1)
    assert_hitcount("query=field8:new york*!*", 1)
    assert_hitcount("query=field10:'n*", 1)
    assert_hitcount("query=field10:wh*", 1)
  end

  def teardown
    stop
  end

end
