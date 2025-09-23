# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class CoveragePolicyTest < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    super
  end

  def test_coverage_policy_node
    set_description("Test that when using coverage-policy 'node' one node at a time is allowed down")
    app = SearchApp.new.cluster(
      SearchCluster.new("mycluster").sd(selfdir + "test.sd").
        redundancy(2).
        ready_copies(2).
        coverage_policy('node').
        group(create_groups(2))).
            storage(StorageCluster.new("mycluster", 2))
    deploy_app(app)
    start

    master_cluster_controller = vespa.storage["mycluster"].get_master_fleet_controller()

    master_cluster_controller.set_node_state("storage", 0, 's:m', 'safe')
    begin
      master_cluster_controller.set_node_state("storage", 1, 's:m', 'safe')
      assert('Should have gotten an exception trying to set a second node to maintenance')
    rescue => e
      assert_equal("Cluster controller refused to set node state to 'maintenance'. Reason: At most one node can have a wanted state: Other storage node 0 has wanted state Maintenance",
                   e.message)
    end
  end

  def create_groups(redundancy)
    NodeGroup.new(0, "mytopgroup").
      distribution("1|*").
      group(NodeGroup.new(0, "mygroup0").
            node(NodeSpec.new("node1", 0)).
            node(NodeSpec.new("node1", 1))).
      group(NodeGroup.new(1, "mygroup1").
            node(NodeSpec.new("node1", 2)).
            node(NodeSpec.new("node1", 3)))
  end


end
