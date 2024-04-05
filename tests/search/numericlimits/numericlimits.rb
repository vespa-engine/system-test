# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class NumericLimits < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_numeric_limits
    set_description("Test that we can feed and search the min and max values of the integer datatypes")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start

    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.json")

    # min values
    assert_hitcount("query=sbytea:-127", 1)
    assert_hitcount("query=sbytea:-128", 0)
    assert_hitcount("query=sbytea:-129", 0)
    assert_hitcount("query=abytea:-128", 1)
    assert_hitcount("query=abytea:-129", 0)
    assert_hitcount("query=wbytea:-128", 1)
    assert_hitcount("query=wbytea:-129", 0)
    assert_hitcount("query=sinta:-2147483647", 1)
    assert_hitcount("query=sinta:-2147483648", 0)
    assert_hitcount("query=sinta:-2147483649", 0)
    assert_hitcount("query=ainta:-2147483648", 1)
    assert_hitcount("query=ainta:-2147483649", 0)
    assert_hitcount("query=winta:-2147483648", 1)
    assert_hitcount("query=winta:-2147483649", 0)
    assert_hitcount("query=slonga:-9223372036854775807", 1)
    assert_hitcount("query=slonga:-9223372036854775808", 0)
    assert_hitcount("query=slonga:-9223372036854775809", 0)
    assert_hitcount("query=alonga:-9223372036854775808", 1)
    assert_hitcount("query=alonga:-9223372036854775809", 1) # Adjusted to int64_t min (but not marked as out of bounds due to out of int64_t range)
    assert_hitcount("query=wlonga:-9223372036854775808", 1)
    assert_hitcount("query=wlonga:-9223372036854775809", 1) # Adjusted to int64_t min (but not marked as out of bounds due to out of int64_t range)

    # max values
    assert_hitcount("query=sbytea:127", 1)
    assert_hitcount("query=sbytea:128", 0)
    assert_hitcount("query=abytea:127", 1)
    assert_hitcount("query=abytea:128", 0)
    assert_hitcount("query=wbytea:127", 1)
    assert_hitcount("query=wbytea:128", 0)
    assert_hitcount("query=sinta:2147483647", 1)
    assert_hitcount("query=sinta:2147483648", 0)
    assert_hitcount("query=ainta:2147483647", 1)
    assert_hitcount("query=ainta:2147483648", 0)
    assert_hitcount("query=winta:2147483647", 1)
    assert_hitcount("query=winta:2147483648", 0)
    assert_hitcount("query=slonga:9223372036854775807", 1)
    assert_hitcount("query=slonga:9223372036854775808", 1) # Adjusted to int64_t max (but not marked as out of bounds due to out of int64_t range)
    assert_hitcount("query=alonga:9223372036854775807", 1)
    assert_hitcount("query=alonga:9223372036854775808", 1) # Adjusted to int64_t max (but not marked as out of bounds due to out of int64_t range)
    assert_hitcount("query=wlonga:9223372036854775807", 1)
    assert_hitcount("query=wlonga:9223372036854775808", 1) # Adjusted to int64_t max (but not marked as out of bounds due to out of int64_t range)

    assert_result("query=sbytea:127", selfdir + "result.max.json")
    assert_result("query=sbytea:-127", selfdir + "result.min.json")
  end

  def teardown
    stop
  end

end
