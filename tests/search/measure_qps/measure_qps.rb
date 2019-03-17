# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MeasureQps < IndexedSearchTest

  def setup
    set_owner("arnej")
    # TODO: find something to test that's still robust on factory
    set_description("Check QPS measurements.");
    search_chain = SearchChain.new("default", "native").
      add(Searcher.new("com.yahoo.search.statistics.PeakQpsSearcher").
         config(ConfigOverride.new("search.statistics.measure-qps").add("outputmethod", "METAHIT")))
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").search_chain(search_chain))
    start
    feed_and_wait_for_docs("music", 10, { :file => SEARCH_DATA+"music.10.xml" })
  end

  def test_meta_hit_exists
    result = search("/?query=nosuchterm&fetchpeakqps")
    assert_match("peak_qps", result.xmldata)
    assert_match("mean_qps", result.xmldata)
  end

  def teardown
    stop
  end

end
