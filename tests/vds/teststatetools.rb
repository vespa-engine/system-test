# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'multi_provider_storage_test'

class TestStateTools < MultiProviderStorageTest

  def setup()
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
  end

  def self.testparameters
     { "PROTON" => { :provider => "PROTON" } }
  end

  def execute_cmd(cmd)
    vespa.storage["storage"].storage["0"].execute(cmd)
  end

  def restart_cluster_controller
    vespa.clustercontrollers["0"].restart
    vespa.clustercontrollers["0"].wait_for_stable_system("storage")
  end

  def test_statetools
        # First check that initial state looks good
    output = execute_cmd("TERM= vespa-get-cluster-state --config-request-timeout 6000 -v")

    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: up/, output)
    assert_match(/storage\/storage\/0: up/, output)
    assert_match(/storage\/storage\/1: up/, output)

        # Set a node down, and observe that this is visible
    output = execute_cmd(
            "TERM= vespa-set-node-state -c storage -t storage -i 0 maintenance \"Yeah, rite\" --config-request-timeout 6000 -v")
    assert_match("OK\n", output)

    output = execute_cmd("TERM= vespa-get-node-state -c storage -t storage -i 0 --config-request-timeout 6000 -v")

    assert_match(/User: maintenance/, output)
    assert_match(/Yeah, rite/, output)

    output = execute_cmd("TERM= vespa-get-cluster-state --config-request-timeout 6000 -v")

    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: up/, output)
    assert_match(/storage\/storage\/0: maintenance/, output)
    assert_match(/storage\/storage\/1: up/, output)

        # Set another node down, checking that the cluster goes down
    output = execute_cmd(
            "TERM= vespa-set-node-state -c storage -t storage -i 1 maintenance \"Yeah, rite\" --config-request-timeout 6000 -v")
    assert_match("OK\n", output)

    output = execute_cmd("TERM= vespa-get-cluster-state --config-request-timeout 6000 -v")

    assert_match(/Cluster storage is down/, output)

        # Set a third node down. Check that this is visible even though the cluster is down.
    output = execute_cmd(
            "TERM= vespa-set-node-state -c storage -t distributor -i 1 down \"Bah\" --config-request-timeout 6000 -v")
    assert_match("OK\n", output)

    output = execute_cmd("TERM= vespa-get-cluster-state --config-request-timeout 6000 -v")

    assert_match(/Cluster storage is down/, output)
    assert_match(/storage\/distributor\/0: up/, output)
    assert_match(/storage\/distributor\/1: down/, output)
    assert_match(/storage\/storage\/0: maintenance/, output)
    assert_match(/storage\/storage\/1: maintenance/, output)
  end

  def test_can_set_state_for_node_not_in_slobrok
    vespa.stop_content_node("storage", 1)
    restart_cluster_controller

    output = execute_cmd(
            "TERM= vespa-set-node-state -c storage -t storage -i 1 maintenance \"bork bork\" --config-request-timeout 6000 -v")
    assert_match("OK\n", output)

    output = execute_cmd("TERM= vespa-get-node-state -c storage -t storage -i 1 --config-request-timeout 6000 -v")

    assert_match(/User: maintenance/, output)
    assert_match(/bork bork/, output)
  end

  def teardown
    stop
  end
end

