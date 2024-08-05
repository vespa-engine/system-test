# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class StopVespa < IndexedStreamingSearchTest

  def can_share_configservers?
    false
  end

  def setup
    set_owner("musum")
    set_description("Test that stopping vespa works well")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    start
  end

  def test_stop_configserver_first
    feed(:file => selfdir+"docs.json")
    wait_for_hitcount("query=sddocname:simple", 2)

    vespa.configservers["0"].stop_configserver

    # query should work even after stopping configserver
    assert_hitcount("query=title:first", 1)

    # stopping vespa should work even after stopping configserver
    vespa.stop_base
  end

  def teardown
    stop
  end
end

