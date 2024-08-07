# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Test_LogicalRank < IndexedStreamingSearchTest
  # Description: Test with logical indexes with different static rank
  # Component: Search and Config
  # Feature: Ranking

  def setup
    set_owner("yngve")
    deploy_app(SearchApp.new.sd(selfdir+"t1.sd").sd(selfdir+"t2.sd"))
    start
  end

  def test_logicalrank
     feed(:file => selfdir + "lr.8.json")

     puts "sanity check"
     wait_for_hitcount("query=test", 8)

     puts "Query: four matches, sorted on weight"
     assert_result("query=test&search=t1", selfdir + "result.1.json")

     puts "Query: four matches, sorted on year"
     assert_result("query=test&search=t2", selfdir + "result.2.json")

  end

  def teardown
    stop
  end
end

