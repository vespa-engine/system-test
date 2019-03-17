# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class NoQueryInSummaryFetch < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that we are not resending the query during summary fetching unnecessarily")
  end

  def test_no_query_in_summary_fetch
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "data.xml")
    
    assert(search_base("query=title:foo&tracelevel=3&timeout=9.9").xmldata.match("Sending 1 summary fetch RPC requests"),
           "Sending summary requests over RPC when query is not needed")
    assert(search_base("query=title:foo&tracelevel=3&ranking.profile=test1&ranking.queryCache=true&timeout=9.9").xmldata.match("Sending 1 summary fetch RPC requests"),
           "Sending summary requests over RPC when query is not needed")
   end

  def teardown
    stop
  end

end
