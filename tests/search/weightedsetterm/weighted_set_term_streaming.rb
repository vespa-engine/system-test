# Copyright Vespa.ai. All rights reserved.
require 'streaming_search_test'
require 'search/weightedsetterm/weighted_set_term_base'

class WeightedSetTermStreaming < StreamingSearchTest

  include WeightedSetTermBase

  def prepare_system(sdfile)
    add_bundle(selfdir + "WeightedSetTermTester.java")
    deploy_app(SearchApp.new.streaming.sd(sdfile).
                      search_chain(SearchChain.new.add(Searcher.new(
                            "com.yahoo.test.WeightedSetTermTester"))))
    start
    feed(:file => selfdir+"docs.json")
    wait_for_hitcount("title:title&streaming.selection=true", 15)
  end

  def test_weighted_set_term_vds
    prepare_system(selfdir + "streaming/blogpost.sd")

    [true, false].each do | strict |
      check_hits(make_query("author", "default", strict, ""), [1, 2, 3])
      check_hits(make_query("likes",  "default", strict, ""), [1, 2, 3, 4])
    end
  end
end
