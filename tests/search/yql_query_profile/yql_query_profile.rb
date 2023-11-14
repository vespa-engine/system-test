# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class YqlQueryProfile < IndexedSearchTest
  def setup
    set_owner("nobody")
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
    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=country", 10)
  end

  def teardown
    stop
  end
end
