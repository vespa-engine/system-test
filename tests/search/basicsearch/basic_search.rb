# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class BasicSearch < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test basic searching")
    @valgrind = false
    @valgrind_opt = nil
  end

  # Override timeout, since the default is very high (1200 seconds) and if
  # this test fails due to some service not starting it
  # will take a very long time before it gives up
  def timeout_seconds
    return 300
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def notest_basicsearch_helgrind
    @valgrind="proton"
    @valgrind_opt="--tool=helgrind --num-callers=30"
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start_feed_and_check
    # assert_no_valgrind_errors
  end

  def test_basicsearch
    deploy_app(SearchApp.new.
               cluster_name("basicsearch").
               sd(SEARCH_DATA+"music.sd"))
    start_feed_and_check
  end

  def start_feed_and_check
    start

    feed(:file => SEARCH_DATA+"music.10.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=country", 1)
    assert_hitcount("query=country&ranking=unranked", 1)
    assert_hitcount("query=title:country", 1)
    assert_hitcount("query=mid:2", 10)
    assert_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=sddocname:music&ranking=unranked", 10)
    assert_result("query=sddocname:music",
                   SEARCH_DATA+"music.10.result.json",
                   "title", ["title", "surl", "mid"])
    assert_result("query=sddocname:music&ranking=unranked",
                   SEARCH_DATA+"music.10.result.json",
                   "title", ["title", "surl", "mid"])
    vespa.search["basicsearch"].first.
    execute("vespa-proton-cmd --local getState")
  end

  def teardown
    stop
  end

end
