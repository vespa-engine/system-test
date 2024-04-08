# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class NumTerm < IndexedStreamingSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("balder")
  end

  def test_numterm
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 2, :file => "#{selfdir}/docs.json")

    assert_hitcount("query=num:5.7",1)
    assert_hitcount("query=str:5.8",1)
    assert_hitcount("query=arr:5.9",1)
    assert_hitcount("query=5.7",1)
    assert_hitcount("query=5.8",1)

    assert_hitcount("query=num:5.8",0)
    assert_hitcount("query=num:5.9",0)
    assert_hitcount("query=str:5.7",0)
    assert_hitcount("query=str:5.9",0)
    assert_hitcount("query=arr:5.7",0)
    assert_hitcount("query=arr:5.8",0)

    assert_hitcount("query=num:5",0)
    assert_hitcount("query=str:5",1)

    assert_hitcount("query=b:23.5",1)
    assert_hitcount("query=d:23.92",1)

    puts "BOLDING:"
    res = search("query=b:23.5&format=xml").xmldata
    puts res
    assert(res.include?("field name=\"b\"><hi>23"))

    puts "DYNAMIC:"
    res = search("query=d:23.92&format=xml").xmldata
    puts res
    assert(res.include?("field name=\"d\"><hi>23"))

    assert_hitcount("query=str:%22complex+words%22", 1)
    assert_hitcount("query=str:yapache-1.155.6", 1)
    assert_hitcount("query=str:1,2,3a", 1)
    assert_hitcount("query=str:a9.4zon", 1)
    assert_hitcount("query=str:1.2-3,4", 1)
    assert_hitcount("query=arr:5",0)
  end

  def teardown
    stop
  end

end
