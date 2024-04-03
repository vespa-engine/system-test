# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ExactMatchUnderscore < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("exact and word match when field name contains underscore (ticket #4558434)")
  end

  def test_exactMatchUnderscore
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start
    feed(:file => "#{selfdir}/feed.json")
    wait_for_hitcount("query=sddocname:simple", 2)

    assert_hitcount("query=brand_name:nike", 1)
    assert_hitcount("query=brand_name:%22adidas+nike%22", 1)

    assert_hitcount("query=array_1:1000", 2)
    assert_hitcount("query=array_1:%221000%22", 2)
    assert_hitcount("query=array_1:%223000+test%22", 1)
    assert_hitcount("query=array_1:%223000@test%22", 1)

    assert_hitcount("query=array_3:1000", 2)
    assert_hitcount("query=array_3:1000@@", 2)
    assert_hitcount("query=array_3:3000+test@@", 1)
    assert_hitcount("query=array_3:3000@test@@", 1)

    assert_hitcount("query=array_1:3000", 0)
    assert_hitcount("query=array_1:test", 0)
    assert_hitcount("query=array_1:3000.test", 0)
    assert_hitcount("query=array_1:3000+test", 0)

    assert_hitcount("query=array_3:3000+test+foo", 0)
    assert_hitcount("query=array_3:3000@test+foo", 0)
    assert_hitcount("query=array_3:3000", 0)
    assert_hitcount("query=array_3:3000@@", 0)

    assert_hitcount("query=brand_name:adidas", 0)
  end

  def teardown
    stop
  end

end
