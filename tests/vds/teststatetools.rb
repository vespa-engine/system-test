# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'vds_test'

class TestStateTools < VdsTest

  def setup()
    set_owner('vekterli')
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
  end

  def execute_cmd(cmd)
    vespa.storage['storage'].storage['0'].execute(cmd)
  end

  def restart_cluster_controller
    vespa.clustercontrollers['0'].restart
    vespa.clustercontrollers['0'].wait_for_stable_system('storage')
  end

  def execute_cli_tool(cmd)
    execute_cmd("TERM= #{cmd} --config-request-timeout 6000 -v")
  end

  def test_statetools
    # First check that initial state looks good
    output = execute_cli_tool('vespa-get-cluster-state')

    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: up/, output)
    assert_match(/storage\/storage\/0: up/, output)
    assert_match(/storage\/storage\/1: up/, output)

    # Set a node down, and observe that this is visible
    output = execute_cli_tool('vespa-set-node-state -c storage -t storage -i 0 maintenance "Yeah, rite"')
    assert_match("OK\n", output)

    output = execute_cli_tool('vespa-get-node-state -c storage -t storage -i 0')

    assert_match(/User: maintenance/, output)
    assert_match(/Yeah, rite/, output)

    output = execute_cli_tool('vespa-get-cluster-state')

    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: up/, output)
    assert_match(/storage\/storage\/0: maintenance/, output)
    assert_match(/storage\/storage\/1: up/, output)

    # Set another node down, checking that the cluster goes down
    output = execute_cli_tool('vespa-set-node-state -c storage -t storage -i 1 maintenance "Yeah, rite"')
    assert_match("OK\n", output)

    output = execute_cli_tool('vespa-get-cluster-state')

    assert_match(/Cluster storage is down/, output)

    # Set a third node down. Check that this is visible even though the cluster is down.
    output = execute_cli_tool('vespa-set-node-state -c storage -t distributor -i 1 down "Bah"')
    assert_match("OK\n", output)

    output = execute_cli_tool('vespa-get-cluster-state')

    assert_match(/Cluster storage is down/, output)
    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: down/, output)
    assert_match(/storage\/storage\/0: maintenance/, output)
    assert_match(/storage\/storage\/1: maintenance/, output)
  end

  def test_vespa_set_node_state_with_safe_mode_condition
    output = execute_cli_tool('vespa-set-node-state -c storage -t storage -i 1 --safe maintenance "bork bork"')
    assert_match("OK\n", output)

    # Content node 1 should be in Maintenance, distributor 1 should be Down
    output = execute_cli_tool('vespa-get-cluster-state')
    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: down/, output)
    assert_match(/storage\/storage\/0: up/, output)
    assert_match(/storage\/storage\/1: maintenance/, output)

    # Trying to set the remaining node into maintenance would violate safety constraints, and should therefore fail
    output = execute_cli_tool('vespa-set-node-state -c storage -t storage -i 0 --safe maintenance "bork bork 2.0"')
    # For some reason the message is broken over 2 lines
    assert_match('At most one node can have a wanted state', output)
    assert_match('Other storage node 1 has wanted state Maintenance', output)

    # Unchanged node states
    output = execute_cli_tool('vespa-get-cluster-state')
    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: down/, output)
    assert_match(/storage\/storage\/0: up/, output)
    assert_match(/storage\/storage\/1: maintenance/, output)
    # Setting the node back up with safe mode shall clear distributor state as well
    output = execute_cli_tool('vespa-set-node-state -c storage -t storage -i 1 --safe up')
    assert_match("OK\n", output)
    
    output = execute_cli_tool('vespa-get-cluster-state')
    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: up/, output)
    assert_match(/storage\/storage\/0: up/, output)
    assert_match(/storage\/storage\/1: up/, output)
  end

  def test_can_set_state_for_node_not_in_slobrok
    vespa.stop_content_node('storage', 1)
    restart_cluster_controller

    output = execute_cli_tool('vespa-set-node-state -c storage -t storage -i 1 maintenance "bork bork"')
    assert_match("OK\n", output)

    output = execute_cli_tool('vespa-get-node-state -c storage -t storage -i 1')

    assert_match(/User: maintenance/, output)
    assert_match(/bork bork/, output)
  end

  def teardown
    stop
  end
end

