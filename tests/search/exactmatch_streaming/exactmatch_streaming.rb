# Copyright Vespa.ai. All rights reserved.

require 'streaming_search_test'

class ExactMatchStreaming < StreamingSearchTest

  def setup
    set_owner("bratseth")
  end

  def test_exact_match_query
    add_bundle("#{selfdir}/ExactMatchSearcher.java")
    deploy_app(SearchApp.new.sd("#{selfdir}/exactmatch.sd").
               search_chain(SearchChain.new("exactmatchchain").
                            add(Searcher.new("com.yahoo.exactmatch.ExactMatchSearcher"))))
    start

    s = '&streaming.selection=true&type=all'
    feed_and_wait_for_docs("exactmatch"+s, 2, :file => "#{selfdir}/feed.json")
    assert_hitcount('query=field1:%22Motors%40York%22'+s, 1)
    assert_hitcount('yql=select+*+from+sources+*+where+[{"defaultIndex":"field1"}]userInput("Motors@York")%3b'+s, 1)
    assert_hitcount('yql=select+*+from+sources+*+where+[{"defaultIndex":"field1","grammar":"raw"}]userInput("Motors@York")%3b'+s, 0)
    assert_hitcount('yql=select+*+from+sources+*+where+[{"defaultIndex":"field1","grammar":"raw"}]userInput("Motors@York@US")%3b'+s, 1)
    assert_hitcount('query=field1:%22Motors%40York%22&searchChain=exactmatchchain'+s, 0)
    assert_hitcount('query=field1:%22Motors%40York%40US%22&searchChain=exactmatchchain'+s, 1)
    assert_hitcount('query=exactfield:hytter'+s, 0)
    assert_hitcount('query=exactfield:hytt'+s, 0)
    assert_hitcount('query=exactfield:hytte'+s, 1)
    assert_hitcount('query=exactfield:hutte'+s, 0)
    assert_hitcount('query=exactfield:hütter'+s, 0)
    assert_hitcount('query=exactfield:hütt'+s, 0)
    assert_hitcount('query=exactfield:hütte'+s, 1)
  end

  def teardown
    stop
  end

end
