# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class SlimeSummary < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_slime_summary
    add_bundle(selfdir + "SummaryInspector.java")
    search_chain = SearchChain.new.add(Searcher.new("com.yahoo.test.SummaryInspector"))
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").search_chain(search_chain))
    start
    feed(:file => selfdir + "docs.json")

    result = search("query=test&slime_docsum")
    assert(result.hit.size == 1)
    assert_check_hit(result, 0)
  end

  def assert_check_hit(result, hit)
    check = result.hit[hit].field["check"]
    assert_equal("ok", check)
  end

  def teardown
    stop
  end

end
