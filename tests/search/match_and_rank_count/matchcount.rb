# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MatchCount < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test that we can accumulate match count per document.")
  end

  def test_match_and_rerank_count_in_query
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "feed.xml")
    verify_counting("test")
  end

  def verify_query(query_in, hitcount, expected, onmatch=nil, onrerank=nil, onsummary=nil)
    query = query_in
    query += "&ranking.properties.vespa.execute.onmatch.attribute=match_count&ranking.properties.vespa.execute.onmatch.operation=#{onmatch}" if onmatch
    query += "&ranking.properties.vespa.execute.onrerank.attribute=second_phase_count&ranking.properties.vespa.execute.onrerank.operation=#{onrerank}" if onrerank
    query += "&ranking.properties.vespa.execute.onsummary.attribute=summary_count&ranking.properties.vespa.execute.onsummary.operation=#{onsummary}" if onsummary
    query += '&format=xml'
    assert_hitcount(query, hitcount)
    r = search(query_in)
    expected.hits.each_with_index { |h,i| h.check_equal(r.hit[i]) }
  end

  def verify_counting(type)
    expected = Hits.new([{"id" => "2", "relevancy" => "2.0"},
                         {"id" => "1", "relevancy" => "1.0"}])
    cmp_fields = ["id", "match_count", "first_phase_count", "second_phase_count", "summary_count", "relevancy"]
    expected.setcomparablefields(cmp_fields)
    query="query=sddocname:#{type}&summary=all_fast&ranking=rank1&format=xml"
    set_counts(expected.hits[0],7,0,0,0)
    set_counts(expected.hits[1],7,0,0,0)
    verify_query(query, 2, expected)
    verify_query(query, 2, expected)

    set_counts(expected.hits[0],8,0,0,0)
    set_counts(expected.hits[1],8,0,0,0)
    verify_query(query, 2, expected, "%2b%2b")
    set_counts(expected.hits[0],9,0,1,0)
    set_counts(expected.hits[1],9,0,0,0)
    verify_query(query, 2, expected, "%2b%2b", "%2b%2b")
    set_counts(expected.hits[0],10,0,2,0)
    set_counts(expected.hits[1],10,0,0,0)
    verify_query(query, 2, expected, "%2b%2b", "%2b%2b")
    set_counts(expected.hits[0],11,0,2,0)
    set_counts(expected.hits[1],11,0,0,0)
    verify_query(query, 2, expected, "%2b%2b")
    set_counts(expected.hits[0],11,0,2,1)
    set_counts(expected.hits[1],11,0,0,1)
    verify_query(query, 2, expected, nil, nil, "%2b%2b")
    set_counts(expected.hits[0],0,0,2,1)
    set_counts(expected.hits[1],0,0,0,1)
    verify_query(query, 2, expected, "=0")
  end

  def set_counts(hit, match, first, second, summary)
    hit.field["match_count"] = "#{match}"
    hit.field["first_phase_count"] = "#{first}"
    hit.field["second_phase_count"] = "#{second}"
    hit.field["summary_count"] = "#{summary}"
  end

  def test_on_xxx_in_rank_profile
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "feed.xml")
    query="query=sddocname:test&summary=all_fast&format=xml"
    all = Hits.new([{"id" => "0"},
		    {"id" => "1"},
		    {"id" => "2"}])
    all.setcomparablefields(["id", "match_count", "first_phase_count", "second_phase_count", "summary_count"])
    expected = Hits.new([{"id" => "2", "relevancy" => "2.0"},
                         {"id" => "1", "relevancy" => "1.0"}])
    expected.setcomparablefields(["id", "match_count", "first_phase_count", "second_phase_count", "summary_count", "relevancy"])

    r = search(query+"&ranking=rank1")
    set_counts(expected.hits[0],7,0,0,0)
    set_counts(expected.hits[1],7,0,0,0)
    expected.hits.each_with_index { |h,i| h.check_equal(r.hit[i]) }

    r = search(query+"&ranking=unranked&sorting=id")
    set_counts(all.hits[0],7,0,0,0)
    set_counts(all.hits[1],7,0,0,0)
    set_counts(all.hits[2],7,0,0,0)
    all.hits.each_with_index { |h,i| h.check_equal(r.hit[i]) }

    search(query+"&ranking=rank2")
    r = search(query+"&ranking=rank1")
    set_counts(expected.hits[0],8,1,1,1)
    set_counts(expected.hits[1],8,1,0,1)
    expected.hits.each_with_index { |h,i| h.check_equal(r.hit[i]) }

    r = search(query+"&ranking=rank2")
    r = search(query+"&ranking=rank1")
    set_counts(expected.hits[0],9,2,2,2)
    set_counts(expected.hits[1],9,2,0,2)
    expected.hits.each_with_index { |h,i| h.check_equal(r.hit[i]) }

    search(query+"&ranking=rank2&hits=1")
    r = search(query+"&ranking=rank1")
    set_counts(expected.hits[0],10,3,3,3)
    set_counts(expected.hits[1],10,3,0,2)
    expected.hits.each_with_index { |h,i| h.check_equal(r.hit[i]) }

    r = search(query+"&ranking=unranked&sorting=id")
    set_counts(all.hits[0],10,0,0,0)
    set_counts(all.hits[1],10,3,0,2)
    set_counts(all.hits[2],10,3,3,3)
    all.hits.each_with_index { |h,i| h.check_equal(r.hit[i]) }
  end

  def teardown
    stop
  end

end
