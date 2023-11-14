# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'json'

class Explain < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test explain feature")
  end

  def test_explain
    deploy_app(SearchApp.new.
               cluster_name("basicsearch").
               sd(SEARCH_DATA+"music.sd"))
    start
    feed(:file => SEARCH_DATA+"music.10.json", :timeout => 240)
    wait_for_hitcount('query=sddocname:music&type=all', 10)
    assert_hitcount('query=title:country&type=all', 1)

    verify_traces(1)
    verify_traces(2)
  end

  def verify_traces(explain_level)
    result = search("/search/?query=sddocname:music&format=json&hits=1&explainlevel=#{explain_level}&tracelevel=1&type=all").json
    puts "verify_traces(#{explain_level}): result=#{result.to_json}"
    children = result["trace"]["children"][1]["children"][0]["children"]
    assert_equal(4, children.size)
    verify_to_dispatch(children[0])
    traces = children[1]["message"][0]["traces"]
    verify_query_setup(traces[0])
    verify_query_execution_plan(traces[1])
    verify_query_execution(traces[2], (explain_level == 2))
  end

  def verify_to_dispatch(result)
    to_dispatch = result["message"]
    assert_match(/sc0.num0 search to dispatch: query=\[\[documentmetastore\]:\*music\*\] timeout=[0-9]+ms offset=0 hits=1 groupingSessionCache=true sessionId=[0-9a-f\-]+.[0-9]+.[0-9].default grouping=0 :  restrict=\[music\]/, to_dispatch)
  end

  def verify_query_setup(trace)
    assert_equal("query_setup", trace["tag"])
    traces = trace["traces"]
    assert_equal("Start query setup",                                           traces[0]["event"])
    assert_equal("Deserialize and build query tree",                            traces[1]["event"])
    assert_equal("Build query execution plan",                                  traces[2]["event"])
    assert_equal("Optimize query execution plan",                               traces[3]["event"])
    assert_equal("Perform dictionary lookups and posting lists initialization", traces[4]["event"])
    assert_equal("Prepare shared state for multi-threaded rank executors",      traces[5]["event"])
    assert_equal("Complete query setup",                                        traces[6]["event"])
  end

  def verify_query_execution_plan(trace)
    assert_equal("query_execution_plan", trace["tag"])
    blueprint = trace["optimized"]
    assert_equal("search::queryeval::AndBlueprint", blueprint["[type]"])
    assert_equal(11, blueprint["docid_limit"])
    estimate = blueprint["estimate"]
    assert_equal(11, estimate["estHits"])
    assert_equal(3, estimate["tree_size"])
    assert_equal(true, estimate["allow_termwise_eval"])
  end

  def verify_query_execution(trace, high_explain_level)
    assert_equal("query_execution", trace["tag"])
    thread_1 = trace["threads"][0]["traces"]
    assert_equal("Start MatchThread::run", thread_1[0]["event"])
    if high_explain_level
      it = thread_1[1]["optimized"]
      assert_equal("search::queryeval::AndSearchStrict<search::queryeval::NoUnpack>", it["[type]"])
    end
    base_idx = high_explain_level ? 2 : 1
    assert_equal("Start match and first phase rank", thread_1[base_idx]["event"])
    assert_equal("Create result set",                thread_1[base_idx + 1]["event"])
    assert_equal("Wait for result processing token", thread_1[base_idx + 2]["event"])
    assert_equal("Start result processing",          thread_1[base_idx + 3]["event"])
    assert_equal("Start thread merge",               thread_1[base_idx + 4]["event"])
    assert_equal("MatchThread::run Done",            thread_1[base_idx + 5]["event"])

    exp_size = high_explain_level ? 8 : 7
    assert_equal(exp_size, thread_1.size)
  end

  def teardown
    stop
  end

end
