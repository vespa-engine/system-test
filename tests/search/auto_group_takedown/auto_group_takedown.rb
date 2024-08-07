# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class GroupAutoTakedownTest < IndexedOnlySearchTest

  def setup
    @valgrind = false # Too many logical nodes to reliably run under Valgrind
    set_owner("vekterli")
    set_description("Test that content cluster 'minimum available nodes per group " +
                    "ratio' feature is able to take groups down and up as expected")
  end

  def teardown
    stop
  end

  def create_app(min_node_ratio:)
    SearchApp.new.
      cluster(SearchCluster.new("foocluster").
              sd(SEARCH_DATA+"test.sd").
              redundancy(3).ready_copies(3).
              min_node_ratio_per_group(min_node_ratio).
              group(NodeGroup.new(0, "root").
                    distribution("1|1|*").
                    group(make_group(0, "g0", [0, 1, 2])).
                    group(make_group(1, "g1", [3, 4, 5])).
                    group(make_group(2, "g2", [6, 7, 8]))))
             .storage(StorageCluster.new("foocluster", 9))
  end

  def make_group(group_index, name, distr_keys)
      group = NodeGroup.new(group_index, name)
      distr_keys.each do |k|
        group.node(NodeSpec.new("node1", k))
      end
      group
  end

  def wait_until_cluster_state_matches(regex)
    vespa.storage["foocluster"].wait_for_state_condition(120) { |state|
      state.statestr =~ regex
    }
  end

  def test_groups_can_be_taken_down_and_up_automatically
    deploy_app(create_app(min_node_ratio: 0.50))
    start

    puts "Taking down 1 node (33% of a group); should not take down entire group"
    stop_node_and_not_wait("foocluster", 4) # 2nd node in 2nd group
    wait_until_cluster_state_matches(/distributor:9 storage:9 \.4\.s:d$/)

    puts "Taking down another node in same group; should take down rest of nodes in group"
    stop_node_and_not_wait("foocluster", 5) # 3rd node in 2nd group
    # "rest of nodes" in this case is node #3
    wait_until_cluster_state_matches(/distributor:9 storage:9 \.3\.s:d \.4\.s:d \.5\.s:d$/)

    puts "Taking one node back up again. This should bring the group back up again"
    start_node_and_wait("foocluster", 4)
    wait_until_cluster_state_matches(/distributor:9 storage:9 \.5\.s:d$/)
  end

  def test_group_availability_can_be_live_reconfigured
    # Start out with the group auto-takedown feature effectively disabled
    deploy_app(create_app(min_node_ratio: 0.0))
    start

    puts "Taking down 1 node (33% of a group); should not take down any other nodes"
    stop_node_and_not_wait("foocluster", 6) # 1st node in 3rd group
    wait_until_cluster_state_matches(/distributor:9 storage:9 \.6\.s:d$/)

    puts "Taking down 1 more node (33% of another group); should not take down any other nodes"
    stop_node_and_not_wait("foocluster", 2) # 3rd node in 1st group
    wait_until_cluster_state_matches(/distributor:9 storage:9 \.2\.s:d \.6\.s:d$/)

    puts "Redeploying with a required availability ratio of 0.75; should take down groups and 1 and 3"
    deploy_app(create_app(min_node_ratio: 0.75))
    # Note "storage:6" rather than "storage:9 .6.s:d (...)". Since all trailing
    # nodes are down, the cluster state is truncated down to an equivalent
    # representation which doesn't mention the nodes explicitly.
    wait_until_cluster_state_matches(/distributor:9 storage:6 \.0\.s:d \.1\.s:d \.2\.s:d$/)

    puts "Redeploying with a required availability ratio of only 0.5; all groups should come back up"
    deploy_app(create_app(min_node_ratio: 0.5))
    wait_until_cluster_state_matches(/distributor:9 storage:9 \.2\.s:d \.6\.s:d$/)
  end

end
