# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class RestartVespa < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test that queries give the same result after restarting Vespa as before")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def can_share_configservers?
    false
  end

  def test_restart
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.json")

    puts "# Query: Before stopping VESPA"
    assert_result("query=song:yellow+-title:yellow", selfdir+"query1.result.json", "surl", ["surl","title"])

    puts "# Stopping Vespa"
    vespa.stop_base
    vespa.adminserver.stop_configserver(:keep_everything => true)
    puts "# Starting Vespa"
    vespa.adminserver.start_configserver
    vespa.adminserver.ping_configserver
    vespa.start_base

    puts "# Wait until ready"
    wait_until_ready
    puts "# System is up"

    wait_for_atleast_hitcount("query=song:yellow", 1)
    puts "# Queries give some hits"

    wait_for_atleast_hitcount("query=sddocname:music", 777)
    puts "# Everything should be ready"

    puts "# Query: After stopping VESPA"
    assert_result("query=song:yellow+-title:yellow", selfdir+"query1.result.json", "surl", ["surl","title"])
  end

  def teardown
    stop
  end

end
