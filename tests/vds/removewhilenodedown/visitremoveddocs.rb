# Copyright Vespa.ai. All rights reserved.
require 'persistent_provider_test'

class VisitRemovedDocs < PersistentProviderTest

  def setup
    set_description("Test that all docs are removed")
    set_owner("vekterli")

    deploy_app(default_app.num_nodes(3).redundancy(2))
    start
  end

  def test_getremoveddocs
    feedfile(selfdir + "10-docs.json")
    # Down storage node 0
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 0, "s:d")
    # Wait until state is "down"
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')

    # Remove docs using <remove> tag
    feedfile(selfdir + "10-remove-docs.json")
    #Bring the node UP
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 0, "s:u")
    # Wait until state is "up"
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('u')

    # Wait until syncing is done
    vespa.storage["storage"].wait_until_ready

    output = vespa.adminserver.execute("VESPA_LOG_TARGET=file:/dev/null vespa-visit -i | sort -u | wc -l")
    assert_equal(0, output.to_i)
  end

  def teardown
    stop
  end
end

