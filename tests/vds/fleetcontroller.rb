# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class FleetControllerTest < VdsTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app.num_nodes(3))
    start
  end

  def test_simple
    vespa.storage["storage"].wait_for_node_count("distributor", 3, "u")
    vespa.storage["storage"].wait_for_node_count("storage", 3, "u")
  end

  def test_manualcontrol
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 1, "s:d")
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')

    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 1, "s:m")
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('m')
  end

  def test_nodedown
    vespa.stop_content_node("storage", "1")
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')

    vespa.storage["storage"].distributor["1"].stop
    vespa.storage["storage"].distributor["1"].wait_for_current_node_state('d')
  end

  def test_nodeinmaintenancestops
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 1, "s:m")
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('m')

    vespa.stop_content_node("storage", "1")
    # Verify that the stopped node is reported as in maintenance
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('m')

    # Change nodestate to down while it is stopped
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 1, "s:d")
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')

    # Start node again. Node should still be reported as down even though the statefile on
    # the node indicates "maintenance" because the fleetcontroller should tell the node to
    # be in DOWN when it comes up again

    wait_for_node_up = false
    vespa.start_content_node("storage", "1", 60, wait_for_node_up)

    # Wait for a while to make sure FleetCtrl has detected that the node has started again
    sleep(10)

    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')

    # Re-enable the node
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 1, "s:u")

    vespa.storage["storage"].storage["1"].wait_for_current_node_state('u')
  end
  
  def storage_cluster
    vespa.storage["storage"]
  end

  def test_user_node_state_persists_between_controller_restart
    cc = vespa.storage["storage"].get_master_fleet_controller()
    cc.set_node_state("storage", 1, "s:d")

    storage_cluster.storage["1"].wait_for_current_node_state('d')
    cc.restart
    # This will time out if state is not persisted between restarts.
    storage_cluster.storage["1"].wait_for_current_node_state('d')
  end

  def teardown
    stop
  end
end

