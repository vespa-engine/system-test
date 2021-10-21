# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=title:country", 1)
    result = search("/search/?query=sddocname:music&format=json&hits=1&explainlevel=1&tracelevel=1").json
    children = result["trace"]["children"][1]["children"][0]["children"]
    assert_equal(4, children.size)
    verify_to_dispatch(children[0])
    verify_traces(children[1]["message"][0]["traces"])

    result = search("/search/?query=sddocname:music&format=json&hits=1&explainlevel=2&tracelevel=1").json
    children = result["trace"]["children"][1]["children"][0]["children"]
    assert_equal(4, children.size)
    verify_to_dispatch(children[0])
    traces = children[1]["message"][0]["traces"]
    verify_traces(traces)
    verify_to_iteratortree(traces[8])
  end

  def verify_traces(traces)
    assert_equal("MTF: Start", traces[0]["event"])
    assert_equal("MTF: Build query", traces[1]["event"])
    assert_equal("MTF: reserve handles", traces[2]["event"])
    assert_equal("MTF: Fetch Postings", traces[3]["event"])
    assert_equal("MTF: Handle Global Filters", traces[4]["event"])
    assert_equal("MTF: prepareSharedState", traces[5]["event"])
    assert_equal("MTF: Complete", traces[6]["event"])
    verify_to_blueprint(traces[7])
  end

  def verify_to_dispatch(result)
    to_dispatch = result["message"]
    assert_match(/sc0.num0 search to dispatch: query=\[\[documentmetastore\]:\*music\*\] timeout=[0-9]+ms offset=0 hits=1 groupingSessionCache=true sessionId=[0-9a-f\-]+.[0-9]+.[0-9].default grouping=0 :  restrict=\[music\]/, to_dispatch)
  end

  def verify_to_blueprint(result)
    blueprint = result["optimized"]
    assert_equal("search::queryeval::AndBlueprint", blueprint["[type]"])
    assert_equal(11, blueprint["docid_limit"])
    estimate = blueprint["estimate"]
    assert_equal(11, estimate["estHits"])
    assert_equal(3, estimate["tree_size"])
    assert_equal(1, estimate["allow_termwise_eval"])
  end

  def verify_to_iteratortree(result)
    thread_1 = result["threads"][0]["traces"]
    assert_equal("Start MatchThread::run", thread_1[0]["event"])
    it = thread_1[1]["optimized"]
    assert_equal("search::queryeval::AndSearchStrict<search::queryeval::NoUnpack>", it["[type]"])
    assert_equal("Start match and first phase rank", thread_1[2]["event"])
    assert_equal("Create result set", thread_1[3]["event"])
    assert_equal("Wait for result processing token", thread_1[4]["event"])
    assert_equal("Start result processing", thread_1[5]["event"])
    assert_equal("Start thread merge", thread_1[6]["event"])
    assert_equal("MatchThread::run Done", thread_1[7]["event"])
    assert_equal(8, thread_1.size)
  end

  def teardown
    stop
  end

end
