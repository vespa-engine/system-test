# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class QrsSummary < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Test that qrs will have old & new summary when changing sd")
  end

  def test_qrs_summary
    # These are messages we want to see from the rejected reconfig
    set_expected_logged(Regexp.union(
            "proton.proton.server.configvalidator	error	Cannot remove attribute field `surl', it still exists as a field",
            "proton.proton.server.documentdb	error	Cannot apply new config snapshot, new schema is in conflict with old schema or history"))
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.json")

    puts "Query: search for concerto in music"
    exp_result = selfdir + "music.result.json"
    assert_result("query=concerto", exp_result)

    puts "Change config (that backend rejects)"
    output = deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    wait_for_application(vespa.container.values.first, output)

    puts "Query: search for concerto in music"
    wait_for_hitcount("query=title:concerto", 1);
    # we can still search in default index due to backend config rejection
    assert_hitcount("query=concerto", 1);
    exp_result = selfdir + "music.proton.result.json"
    poll_compare("query=title:concerto", exp_result)
    
    # also check after a restart
    puts "Restarting"
    vespa.stop_base
    vespa.start_base
    puts "Query: search for concerto in music"
    wait_for_hitcount("query=title:concerto", 1);
    # we can still search in default index due to backend config rejection
    assert_hitcount("query=concerto", 1);
    exp_result = selfdir + "music.proton.result.json"
    poll_compare("query=title:concerto", exp_result)
  end

  def teardown
    stop
  end

end
