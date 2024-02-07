# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'json'

class QueryProfiling < IndexedOnlySearchTest
  
  def setup
    @global_filter_tag = "global_filter_profiling"
    @match_tag         = "match_profiling"
    @first_phase_tag   = "first_phase_profiling"
    @second_phase_tag  = "second_phase_profiling"
    set_owner('havardpe')
    set_description("Test query profiling (matching/ranking)")
  end

  def test_query_profiling
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_for_docs('test', 5, :file => selfdir + 'docs.json')
    for depth in [1,3,-1,-3] do
      verify_match_profiling(depth)
      verify_first_phase_profiling(depth)
      verify_second_phase_profiling(depth)
    end
  end

  def make_query(depth_name, depth_value)
    result = "yql=select * from sources * where {targetHits:10,approximate:true}nearestNeighbor(vec,qvec) and title contains 'foo'"
    result += "&ranking.features.query(qvec)=[1,1]"
    result += "&trace.explainLevel=2&tracelevel=1&trace.#{depth_name}=#{depth_value}"
    return result
  end
  
  def get_query_traces(query)
    result = search(query).json
    traces = result["trace"]["children"][1]["children"][0]["children"][1]["message"][0]["traces"]
    return traces
  end
  
  def verify_match_profiling(depth)
    puts "test case: match(#{depth})"
    verify_match_trace(get_query_traces(make_query("profileDepth", depth)), depth, exclusive: false)
    puts "test case: match(#{depth}) exclusive"
    verify_match_trace(get_query_traces(make_query("profiling.matching.depth", depth)), depth, exclusive: true)
  end

  def verify_first_phase_profiling(depth)
    puts "test case: first_phase(#{depth})"
    verify_first_phase_trace(get_query_traces(make_query("profileDepth", depth)), depth, exclusive: false)
    puts "test case: first_phase(#{depth}) exclusive"
    verify_first_phase_trace(get_query_traces(make_query("profiling.firstPhaseRanking.depth", depth)), depth, exclusive: true)
  end

  def verify_second_phase_profiling(depth)
    puts "test case: second_phase(#{depth})"
    verify_second_phase_trace(get_query_traces(make_query("profileDepth", depth)), depth, exclusive: false)
    puts "test case: second_phase(#{depth}) exclusive"
    verify_second_phase_trace(get_query_traces(make_query("profiling.secondPhaseRanking.depth", depth)), depth, exclusive: true)
  end

  def find_entry(traces, tag, verify: false)
    entry = traces.find { |item| item["tag"] == tag }
    if verify
      assert(!entry.nil?)
      assert_equal(entry["tag"], tag)
    end
    return entry
  end

  def get_thread_traces(trace, thread_id)
    assert_equal(trace["threads"].size, 4)
    return trace["threads"][thread_id]["traces"]
  end

  def verify_match_trace(traces, depth, exclusive: false)
    query_setup_trace = find_entry(traces, "query_setup", verify: true)
    global_filter_trace = find_entry(query_setup_trace["traces"], "global_filter_execution", verify: true)
    for thread_id in 0..3 do
      filter = find_entry(get_thread_traces(global_filter_trace, thread_id), @global_filter_tag, verify: true)
      if thread_id == 0
        puts "profile result: #{JSON.pretty_generate(filter)}"
      end
      verify_profiler_result(filter, depth)
      assert(filter["roots"][0]["name"].start_with?("/"))
    end
    trace = find_entry(traces, "query_execution", verify: true)
    for thread_id in 0..3 do
      match = find_entry(get_thread_traces(trace, thread_id), @match_tag, verify: true)
      if thread_id == 0
        puts "profile result: #{JSON.pretty_generate(match)}"
      end
      if exclusive
        assert(find_entry(get_thread_traces(trace, thread_id), @first_phase_tag).nil?)
        assert(find_entry(get_thread_traces(trace, thread_id), @second_phase_tag).nil?)
      end
      verify_profiler_result(match, depth)
      assert(match["roots"][0]["name"].start_with?("/"))
    end
  end

  def verify_first_phase_trace(traces, depth, exclusive: false)
    trace = find_entry(traces, "query_execution", verify: true)
    docs_ranked = 0
    for thread_id in 0..3 do
      first_phase = find_entry(get_thread_traces(trace, thread_id), @first_phase_tag, verify: true)
      if thread_id == 0
        puts "profile result: #{JSON.pretty_generate(first_phase)}"
      end
      if exclusive
        assert(find_entry(get_thread_traces(trace, thread_id), @match_tag).nil?)
        assert(find_entry(get_thread_traces(trace, thread_id), @second_phase_tag).nil?)
      end
      verify_profiler_result(first_phase, depth)
      if depth > 0
        assert(first_phase["roots"][0]["name"].include?("first_foo"))
      end
      docs_ranked += first_phase["roots"][0]["count"]
    end
    assert_equal(docs_ranked, 5)
  end

  def verify_second_phase_trace(traces, depth, exclusive: false)
    trace = find_entry(traces, "query_execution", verify: true)
    for thread_id in 0..3 do
      second_phase = find_entry(get_thread_traces(trace, thread_id), @second_phase_tag, verify: true)
      if thread_id == 0
        puts "profile result: #{JSON.pretty_generate(second_phase)}"
      end
      if exclusive
        assert(find_entry(get_thread_traces(trace, thread_id), @match_tag).nil?)
        assert(find_entry(get_thread_traces(trace, thread_id), @first_phase_tag).nil?)
      end
      verify_profiler_result(second_phase, depth)
      if depth > 0
        assert(second_phase["roots"][0]["name"].include?("second_foo"))
      end
    end
  end

  def verify_profiler_result(profile, depth)
    if depth < 0
      assert_equal(profile["profiler"], "flat")
      assert_equal(profile["topn"], -depth)
      assert_operator profile["roots"].size, :<= ,-depth
      for entry in profile["roots"] do
        verify_depth(entry, 0)
      end
    else
      assert_equal(profile["profiler"], "tree")
      assert_equal(profile["depth"], depth)
      for entry in profile["roots"] do
        verify_depth(entry, depth - 1)
      end
    end
  end

  def verify_depth(profile, depth)
    assert_operator depth, :>=, 0
    unless profile["children"].nil?
      for child in profile["children"] do
        verify_depth(child, depth - 1)
      end
    end
  end
  
  def teardown
    stop
  end

end
