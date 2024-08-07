# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class FederationTimeoutsTest < SearchContainerTest

  def setup
    set_owner("bratseth")
    set_description("Some federation timeout testing")
  end

  def test_federation
    add_bundle(selfdir+"WaitingSearcher.java");
    deploy(selfdir + "app")
    start

    wait_for_atleast_hitcount("query=test&hits=2",0)

    # Query both sources and check that the timeout setting is used for waiting
    # (such that we do not timeout the test), while the query timeout
    # exposed to the chain is the requestTimeout (logged by the WaitingSearcher)
    # Note also that we could use the functionality of WaitingSearcher for various other tests
    # by passing the pause time downwards.
    result=search_base("query=test")
    assert_log_matches("Query timeout in one: 1000000")
    assert_log_matches("Query timeout in two: 1000")
  end

  def teardown
    stop
  end

end
