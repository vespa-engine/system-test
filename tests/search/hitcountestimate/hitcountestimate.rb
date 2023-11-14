# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class HitcountEstimate < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Check hit count estimate queries work.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_hitcountestimate
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.xml", :name => "music")
    result = search("/?query=sddocname:music&hitcountestimate&nocache")
    assert(result.hit.size == 0, "Expected no hits returned for an estimate query, got #{result.hit.size}")
    assert(result.hitcount == 10, "Expected 10 in total result size, got #{result.hitcount}")
  end

  def teardown
    stop
  end

end
