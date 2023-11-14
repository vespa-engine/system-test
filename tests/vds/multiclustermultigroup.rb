# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_multi_model_test'

class MultiClusterMultiGroup < VdsMultiModelTest

  def self.testparameters
    { "PROTON" => { :provider => "PROTON" }}
  end

  def timeout_seconds
    1600
  end

  def setup
    set_owner("vekterli")
    @valgrind = false
    deploy_app(StorageApp.new.
               storage_cluster(
                               StorageCluster.new("clusterA").
                               redundancy(2).
                           group(NodeGroup.new(0, "clusterA").
                                 distribution("1|*").
                                 group(
                                       NodeGroup.new(0, "switch0").
                                       distribution("*").
                                       group(
                                             NodeGroup.new(0, "copy0").
                                             node(NodeSpec.new("node1", 0)).
                                             node(NodeSpec.new("node1", 1))).
                                       group(
                                             NodeGroup.new(1, "copy1").
                                             node(NodeSpec.new("node1", 2)).
                                             node(NodeSpec.new("node1", 3)))).
                                 group(
                                       NodeGroup.new(1, "switch1").
                                       node(NodeSpec.new("node1", 4)).
                                       node(NodeSpec.new("node1", 5)))).
                           sd(VDS + "/schemas/music.sd").
                           transition_time(0).
                           disable_fleet_controllers(true)).
           storage_cluster(
                           StorageCluster.new("clusterB").
                           redundancy(2).
                           group(NodeGroup.new(0, "clusterB").
                                 distribution("1|*").
                                 group(
                                       NodeGroup.new(0, "switch0").
                                       distribution("*").
                                       group(
                                             NodeGroup.new(0, "copy0").
                                             node(NodeSpec.new("node1", 0)).
                                             node(NodeSpec.new("node1", 1))).
                                       group(
                                             NodeGroup.new(1, "copy1").
                                             node(NodeSpec.new("node1", 2)).
                                             node(NodeSpec.new("node1", 3)))).
                                 group(
                                       NodeGroup.new(1, "switch1").
                                       node(NodeSpec.new("node1", 8)).
                                       node(NodeSpec.new("node1", 9)))).
                           sd(VDS + "/schemas/music.sd").
                           transition_time(0).
                           disable_fleet_controllers(true)).
               clustercontroller("node1").
               sd(VDS + "/schemas/music.sd"));
    start
  end

  def test_multiclustermultigroup
    vespa.stop_content_node("clusterA", 0)
    vespa.stop_content_node("clusterB", 3)
  end

  def teardown
    stop
  end

end
