# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'search/weightedsetterm/weighted_set_term_base'

class WeightedSetTerm < IndexedStreamingSearchTest

  include WeightedSetTermBase

  def prepare_system(sdfile)
    add_bundle(selfdir + "WeightedSetTermTester.java")
    deploy_app(SearchApp.new.sd(sdfile).
                      indexing_cluster('default').indexing_chain('indexing').
                      search_chain(SearchChain.new.add(Searcher.new(
                            "com.yahoo.test.WeightedSetTermTester"))))
    start
    feed(:file => selfdir+"docs.xml")
    wait_for_hitcount("title:title&streaming.selection=true", 15)
  end

  def test_weighted_set_term
    prepare_system(selfdir + "blogpost.sd")

    ["", "_indexed", "_string_attr"].each do | suffix |
      [true, false].each do | strict |
        check_hits(make_query("author", "",       strict, suffix), [1, 2, 3])
        check_hits(make_query("author", "weight", strict, suffix), [1, 2, 3])
        check_hits(make_query("author", "count",  strict, suffix), [1, 2, 3])

        check_rank(make_query("author", "weight", strict, suffix), [10, 20, 30])
        check_rank(make_query("author", "count",  strict, suffix), [1, 1, 1])

        check_hits(make_query("likes",  "",       strict, suffix), [1, 2, 3, 4])
        check_hits(make_query("likes",  "weight", strict, suffix), [1, 2, 3, 4])
        check_hits(make_query("likes",  "count",  strict, suffix), [1, 2, 3, 4])

        check_rank(make_query("likes",  "weight", strict, suffix), [10, 20, 30, 30])
        check_rank(make_query("likes",  "count",  strict, suffix), [1, 2, 3, 3])
      end
    end
  end
end
