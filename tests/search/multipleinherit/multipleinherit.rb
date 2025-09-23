# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class MultipleInherit < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
    set_description("Document type inherits from 2 or more document types")
    sdfiles = ["base1.sd", "base2.sd", "derived.sd"]
    app = SearchApp.new
    sdfiles.each { |sd| app.sd(selfdir+sd) }
    deploy_app(app)
    start
  end

  def test_multiple_inherit
    feed_and_wait_for_docs("derived", 1, :file => selfdir+"testmultiinheritance.3.json")
    # Only one result, since sddocname now names the most derived type.
    wait_for_hitcount("query=common&search=base1", 1)

    regexp = /total-hit-count|common|sddocname/
    puts "Query: Test that common is present in base1"
    assert_result("query=common&search=base1", selfdir+"test1.result.json")

    puts "Query: Test that common is present in base2"
    assert_result("query=common&search=base2", selfdir+"test2.result.json")

    puts "Query: Test that common is present in derived only"
    assert_result("query=common&search=derived", selfdir+"test3.result.json")

    puts "Query: Test that all fields are in the derived class"
    assert_result("query=field2:f2d1+field5:f5d1&search=derived", selfdir+"test4.result.json")
  end


end
