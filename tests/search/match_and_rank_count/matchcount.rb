# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MatchCount < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test that we can accumulate match count per document.")
  end

  def test_match_and_rerank_count
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.xml")
    verify_counting("test")
  end

  def verify_query(query_in, hitcount, expected, onmatch=nil, onrerank=nil, onsummary=nil)
    query = query_in
    query += "&ranking.properties.vespa.execute.onmatch.attribute=match_count&ranking.properties.vespa.execute.onmatch.operation=#{onmatch}" if onmatch
    query += "&ranking.properties.vespa.execute.onrerank.attribute=rerank_count&ranking.properties.vespa.execute.onrerank.operation=#{onrerank}" if onrerank
    query += "&ranking.properties.vespa.execute.onsummary.attribute=summary_count&ranking.properties.vespa.execute.onsummary.operation=#{onsummary}" if onsummary
    assert_hitcount(query, hitcount)
    assert_result(query_in, selfdir + expected, nil, ["id", "f1", "match_count", "rerank_count","summary_count", "relevancy"])
  end

  def verify_counting(type)
    query="query=sddocname:#{type}&summary=all_fast&ranking=rank1"
    verify_query(query, 2, "result.xml")
    verify_query(query, 2, "result.xml")
    verify_query(query, 2, "result1.xml", "%2b%2b")
    verify_query(query, 2, "result2.xml", "%2b%2b", "%2b%2b")
    verify_query(query, 2, "result3.xml", "%2b%2b", "%2b%2b")
    verify_query(query, 2, "result4.xml", "%2b%2b")
    verify_query(query, 2, "result5.xml", nil, nil, "%2b%2b")
    verify_query(query, 2, "result6.xml", "=0")
  end

  def teardown
    stop
  end

end
