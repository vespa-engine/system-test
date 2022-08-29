# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'json'

class RankProfiling < IndexedSearchTest

  def setup
    set_owner('havardpe')
    set_description("Test rank feature profiling")
  end

  def test_rank_profiling
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_for_docs('test', 5, :file => selfdir + 'docs.json')
    verify_profiling(1)
    verify_profiling(3)
  end
  
  def verify_profiling(profile_depth)
    result = search("/search/?query=sddocname:test&format=json&hits=1&tracelevel=1&trace.profileDepth=#{profile_depth}&type=all").json
    puts "verify_profiling(#{profile_depth}): result=#{JSON.pretty_generate(result)}"
    traces = result["trace"]["children"][1]["children"][0]["children"][1]["message"][0]["traces"]
    assert_equal(traces[0]["tag"], "query_execution")
    assert_equal(traces[0]["threads"].size, 4)
    sum  = verify_thread_trace(traces[0]["threads"][0]["traces"], profile_depth)
    sum += verify_thread_trace(traces[0]["threads"][1]["traces"], profile_depth)
    sum += verify_thread_trace(traces[0]["threads"][2]["traces"], profile_depth)
    sum += verify_thread_trace(traces[0]["threads"][3]["traces"], profile_depth)
    assert_equal(sum, 5)
  end
  
  def verify_thread_trace(trace, depth)
    assert_equal(trace[0]["tag"], "first_phase_profiling")
    assert_equal(trace[1]["tag"], "second_phase_profiling")
    assert(trace[0]["roots"][0]["name"].include?("first_foo"))
    assert(trace[1]["roots"][0]["name"].include?("second_foo"))
    verify_depth(trace[0]["roots"][0], depth - 1)
    verify_depth(trace[1]["roots"][0], depth - 1)
    return trace[0]["roots"][0]["count"]
  end

  def verify_depth(profile, depth)
    assert((depth > 0) == (!profile["children"].nil?))
    if (depth > 0)
      verify_depth(profile["children"][0], depth - 1)
    end
  end
  
  def teardown
    stop
  end

end
