# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'

class BucketReplicaActivationTest < SearchTest

  def setup
    @valgrind=false
    set_owner("vekterli")
    set_description("Test that taking a node down and up will update " +
                    "which bucket replicas are active across the cluster")

    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
               elastic.cluster_name("storage").num_parts(3).redundancy(2).
               storage(StorageCluster.new("storage", 3).distribution_bits(10)))
    start
  end

  def teardown
    stop
  end
  
  def content_cluster
    vespa.storage['storage']
  end

  def verify_single_replica_active_per_bucket
    content_cluster.validate_cluster_bucket_state(:check_active => true)
  end

  def wait_until_content_node_processes_reach_state(index, state)
    content_cluster.distributor[index.to_s].wait_for_current_node_state(state)
    content_cluster.storage[index.to_s].wait_for_current_node_state(state)
  end

  def test_single_replica_is_activated_per_bucket
    feed(:file => SEARCH_DATA + 'music.10000.xml')

    # All data shall have been fully activated as part of the feeding.
    verify_single_replica_active_per_bucket

    content_cluster.distributor["1"].stop
    vespa.stop_content_node("storage", "1")
    wait_until_content_node_processes_reach_state(1, 'd')
    content_cluster.wait_until_ready(600, ["1"])

    verify_single_replica_active_per_bucket

    content_cluster.distributor["1"].start
    vespa.start_content_node("storage", "1")
    wait_until_content_node_processes_reach_state(1, 'u')
    content_cluster.wait_until_ready(600)

    verify_single_replica_active_per_bucket
  end

end
