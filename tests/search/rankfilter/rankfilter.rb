# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class RankFilter < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_rank_filter
    set_description("Test that we use bit vector for rank filter fields")
    add_bundle(selfdir + "NoPositionDataSearcher.java")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
                      search_chain(SearchChain.new.add(Searcher.new(
                          "com.yahoo.rankfilter.NoPositionDataSearcher"))))
    start
    vespa.adminserver.logctl("searchnode:diskindex.disktermblueprint", "debug=on")
    vespa.adminserver.logctl("searchnode:proton.memoryindex.memoryindex", "debug=on")
    feed_and_wait_for_docs("test", 1, :file => selfdir + "test.json")

    if is_streaming
      puts "Run tests for streaming search"
      run_rank_filter_test
      return
    end
    puts "Run tests for memory index"
    run_rank_filter_test

    # make sure the memory index is flushed to disk
    node = vespa.search["search"].first
    20.times do
      node.trigger_flush
      if vespa.logserver.log_matches(/.*flush\.complete.*memoryindex/) == 1
        break
      end
      puts "Sleep 2 seconds before next trigger_flush"
      sleep 2
    end
    assert_log_matches(/.*diskindex\.load\.complete/)
    assert_log_matches(/.*flush\.complete.*memoryindex/)

    puts "Run tests for disk index"
    run_rank_filter_test
  end

  def run_rank_filter_test
    no_pos = 1000000
    assert_pos("f1", no_pos, "f1:a")
    assert_pos("f2", 2, "f2:a")
    assert_pos("f2", no_pos, "f2:a&noposdata")
    assert_pos("f2", no_pos, "f2:a&ranking=f2-filter")
    # f3 and f4 have independent rank config
    assert_pos("f3", 3, "f3:a")
    assert_pos("f3", 3, "a")
    assert_pos("f4", no_pos, "f4:a")
    assert_pos("f4", no_pos, "a")
  end

  def assert_pos(field, fpos, query)
    query = "query=" + query + "&nocache&type=all"
    result = search(query)
    exp = {"fieldTermMatch(#{field},0).firstPosition" => fpos}
    assert_features(exp, result.hit[0].field['summaryfeatures'], 1e-4)
  end

  def teardown
    stop
  end

end
