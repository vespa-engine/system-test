# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class YqlQueryProfile < IndexedStreamingSearchTest
  def setup
    set_owner("bjorncs")
    set_description("Test Query Profiles with userQuery() in YQL+")
  end

  def test_yqlsearch
    deploy_app(SearchApp.new.
               search_dir(selfdir + "search").
               cluster_name("basicsearch").
               sd(SEARCH_DATA+"music.sd"))
    start_feed_and_check
  end

  def start_feed_and_check
    start
    feed_and_check
  end

  def feed_and_check
    feed(:file => SEARCH_DATA+"music.10.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=country", 10)
  end

  def teardown
    stop
  end
end
