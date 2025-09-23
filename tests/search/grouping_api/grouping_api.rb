# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class GroupingApi < IndexedStreamingSearchTest

  def setup
    set_owner("bjorncs")
    add_bundle(selfdir+"TestSearcher.java");
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.search.grouping.test.TestSearcher", "transformedQuery", "blendedResult"))
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").search_chain(search_chain))
    start
  end

  def test_groupingapi
    feed_and_wait_for_docs("test", 4, :file => "#{selfdir}/docs.json")
    result = search("query=test")
    puts(result.xmldata);
    assert_equal(4, result.hitcount)
    assert(result.xmldata.include?("PASS: min"))
    assert(result.xmldata.include?("PASS: max"))
    assert(result.xmldata.include?("PASS: average"))
  end


end
