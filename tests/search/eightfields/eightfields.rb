# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class EightFields < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Index 8 fields in one index.")
    deploy_app(SearchApp.new.sd(selfdir+"test8fields.sd"))
    start
  end

  def test_eightfields
    feed_and_wait_for_docs("test8fields", 8, :file => selfdir+"eightfields.8.xml")

    puts "Query: Search for 8 terms, where each term is found in a different field, same document"
    assert_hitcount("query=eightfields:f1d3%20eightfields:f2d3%20eightfields:f3d3%20eightfields:f4d3%20eightfields:f5d3%20eightfields:f6d3%20eightfields:f7d3%20eightfields:f8d3", 1)

    puts "Query: Search for terms belonging to different documents, and different fields"
    assert_hitcount("query=(eightfields:f1d1%20eightfields:f2d2%20eightfields:f3d3%20eightfields:f4d4%20eightfields:f5d5%20eightfields:f6d6%20eightfields:f7d7%20eightfields:f8d8)", 8)
  end

  def teardown
    stop
  end

end
