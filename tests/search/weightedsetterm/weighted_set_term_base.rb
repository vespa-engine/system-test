# Copyright Vespa.ai. All rights reserved.
require 'search_test'

module WeightedSetTermBase
  def setup
    set_owner("arnej")
    set_description("test weighted set query term searching")
  end

  def teardown
    stop
  end

  def make_query(field, rank, strict, suffix)
    query = "query=title:foo"
    tokens = "ws.tokens=100:1000,1:10,2:20,3:30"
    if strict
      query = "query="
    else
      tokens += ",10:100"
    end
    query += "&#{tokens}&ws.field=#{field}#{suffix}"
    if rank != "" and rank != "default"
      query += "&ranking=#{rank}_#{field}#{suffix}"
    end
    query += "&streaming.selection=true"
    query += "&tracelevel=4"
    return query
  end

  def check_hits(query, list)
    puts "checking hits for query: " + query
    result = search(query)
    assert_equal(list.size, result.hitcount)
    result.sort_results_by("timestamp")
    list.each_index do |i|
      assert_equal("id:test:blogpost::#{list[i]}", result.hit[i].field["documentid"])
    end
  end

  def check_rank(query, list)
    puts "checking rank for query: " + query
    result = search(query)
    assert_equal(list.size, result.hitcount)
    result.sort_results_by("timestamp")
    list.each_index do |i|
      assert_equal(Float(list[i]), Float(result.hit[i].field["relevancy"]))
    end
  end
end
