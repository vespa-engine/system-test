# Copyright Vespa.ai. All rights reserved.
require 'vds_multi_model_test'
require 'securerandom'

class HierarchDistr < VdsMultiModelTest

  def setup
    @distribution_bits = 12
    set_owner("vekterli")
  end

  def timeout_seconds
    1600
  end

  def tempfile_name(postfix)
    "#{SecureRandom.urlsafe_base64}_#{postfix}"
  end

  def app2
               StorageApp.new.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
                   distribution_bits(@distribution_bits).
                   group(NodeGroup.new(0, "mycluster").
                     distribution("1|*").
                     group(
                           NodeGroup.new(0, "switch0").
                           node(NodeSpec.new("node1", 0)).
                           node(NodeSpec.new("node1", 1))).
                     group(
                           NodeGroup.new(1, "switch1").
                           node(NodeSpec.new("node1", 2)).
                           node(NodeSpec.new("node1", 3))))).
               sd(VDS + "/schemas/music.sd").
               transition_time(0).
               validation_override("redundancy-increase")
  end

  def app3
               StorageApp.new.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
                   distribution_bits(@distribution_bits).
                   group(NodeGroup.new(0, "mycluster").
                     distribution("*").
                     group(
                           NodeGroup.new(0, "switch0").
                           node(NodeSpec.new("node1", 0)).
                           node(NodeSpec.new("node1", 1)).
                           node(NodeSpec.new("node1", 2))).
                     group(
                           NodeGroup.new(1, "switch1").
                           node(NodeSpec.new("node1", 3)).
                           node(NodeSpec.new("node1", 4))))).
               sd(VDS + "/schemas/music.sd").
               transition_time(0).
               validation_override("redundancy-increase")
  end

  def app4
               StorageApp.new.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
                   distribution_bits(@distribution_bits).
                   group(NodeGroup.new(0, "mycluster").
                     distribution("*|*").
                     group(
                           NodeGroup.new(0, "switch0").
                           distribution("1|*").
                           group(
                                 NodeGroup.new(0, "rack0").
                                 node(NodeSpec.new("node1", 0))).
                           group(
                                 NodeGroup.new(1, "rack1").
                                 node(NodeSpec.new("node1", 1)))).
                     group(
                           NodeGroup.new(1, "switch1").
                           distribution("*").
                           group(
                                 NodeGroup.new(0, "rack0").
                                 node(NodeSpec.new("node1", 2))).
                           group(
                                 NodeGroup.new(1, "rack1").
                                 node(NodeSpec.new("node1", 3)))))).
               sd(VDS + "/schemas/music.sd").
               transition_time(0).
               validation_override("redundancy-increase")
 end

  def deploy_and_wait(app, start_services=nil)
    config_generation = get_generation(deploy_app(app)).to_i
    start if start_services
    wait_for_config_generation(vespa.storage["storage"].storage, config_generation)
    wait_for_config_generation(vespa.storage["storage"].distributor, config_generation)
  end

  def wait_for_config_generation(nodes, config_generation)
    nodes.each_value do |node|
      node.wait_for_config_generation(config_generation)
    end
  end

  def nohierarchy
               StorageApp.new.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
                   distribution_bits(@distribution_bits).
                   group(NodeGroup.new(0, "mycluster").
                      node(NodeSpec.new("node1", 0)).
                      node(NodeSpec.new("node1", 1)).
                      node(NodeSpec.new("node1", 2)).
                      node(NodeSpec.new("node1", 3)))).
               sd(VDS + "/schemas/music.sd").
               transition_time(0).
               validation_override("redundancy-increase")
  end

  def test_app_change
    @valgrind = false
    deploy_and_wait(app2, true)
    feed_and_get_all_documents

    deploy_and_wait(app4)
    vespa.storage["storage"].wait_until_ready(300)

    get_all_docs

    deploy_and_wait(nohierarchy)
    vespa.storage["storage"].wait_until_ready(300)

    get_all_docs
  end

  def test_app2
    deploy_and_wait(app2, true)
    feed_and_get_all_documents

    set0 = get_buckets(0)
    set1 = get_buckets(1)
    set2 = get_buckets(2)
    set3 = get_buckets(3)

    # no overlap within switches
    assert set0.intersection(set1).empty?
    assert set2.intersection(set3).empty?

    # full overlap between switches
    assert set0.union(set1) == set2.union(set3)

    # should have cross-switch overlap
    assert !set0.intersection(set2).empty?
    assert !set0.intersection(set3).empty?
    assert !set1.intersection(set2).empty?
    assert !set1.intersection(set3).empty?

    # take down switch 0
    vespa.stop_content_node('storage', 0)
    vespa.stop_content_node('storage', 1)

    get_all_docs
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_ready(300)

    # all data should still be available
    get_all_docs
  end


  def test_app3
    deploy_and_wait(app3, true)
    feed_and_get_all_documents

    set0 = get_buckets(0)
    set1 = get_buckets(1)
    set2 = get_buckets(2)
    set3 = get_buckets(3)
    set4 = get_buckets(4)

    # should have full overlap within switch 1
    assert set3 == set4

    # should not have full overlap within switch 0
    assert set0 != set1
    assert set0 != set2
    assert set1 != set2

    # should have no overlap between switches
    set012 = set0.union(set1).union(set2)
    set34 = set3.union(set4)
    assert set012.intersection(set34).empty?

    # take down node 0 in switch 0
    vespa.stop_content_node('storage', 0)
    get_all_docs
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_ready(300)

    set1new = get_buckets(1)
    set2new = get_buckets(2)
    set3new = get_buckets(3)
    set4new = get_buckets(4)

    # data redistribution should happen only within switch 0
    assert set1new != set1
    assert set2new != set2
    assert set3new == set3
    assert set4new == set4

    # should have recovered all data
    set12new = set1.union(set2)
    assert set12new == set012

    # all data should still be available
    get_all_docs
  end


  def test_app4
    deploy_and_wait(app4, true)
    feed_and_get_all_documents

    set0 = get_buckets(0)
    set1 = get_buckets(1)
    set2 = get_buckets(2)
    set3 = get_buckets(3)

    # should not have overlap within racks
    assert set0.intersection(set1).empty?
    assert set2.intersection(set3).empty?

    # should have cross-switch overlap
    assert !set0.intersection(set2).empty?
    assert !set0.intersection(set3).empty?
    assert !set1.intersection(set2).empty?
    assert !set1.intersection(set3).empty?

    # should have full overlap between switches
    set01 = set0.union(set1)
    set23 = set2.union(set3)
    assert set01 == set23

    # take down node 0 in switch 0 rack 0
    vespa.stop_content_node('storage', 0)
    get_all_docs
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_ready(300)

    set1new = get_buckets(1)
    set2new = get_buckets(2)
    set3new = get_buckets(3)

    # no data should be redistributed
    assert set1new == set1
    assert set2new == set2
    assert set3new == set3

    # all data should still be available
    get_all_docs
  end

  def app_3x3_with_pseudo_row_column
    StorageApp.new.storage_cluster(
      StorageCluster.new("storage").
        redundancy(3).
        distribution_bits(@distribution_bits).
        pseudo_row_column_mode(true).
        group(NodeGroup.new(0, "mycluster").
          distribution("*|*|*").
          group(
            NodeGroup.new(0, "g0").
              node(NodeSpec.new("node1", 0)).
              node(NodeSpec.new("node1", 1)).
              node(NodeSpec.new("node1", 2))).
          group(
            NodeGroup.new(1, "g1").
              node(NodeSpec.new("node1", 3)).
              node(NodeSpec.new("node1", 4)).
              node(NodeSpec.new("node1", 5))).
          group(
            NodeGroup.new(2, "g3").
              node(NodeSpec.new("node1", 6)).
              node(NodeSpec.new("node1", 7)).
              node(NodeSpec.new("node1", 8))))).
      sd(VDS + "/schemas/music.sd").
      transition_time(0)
  end

  def test_node_order_relative_replica_placement
    deploy_app(app_3x3_with_pseudo_row_column)
    start
    feed_and_get_all_documents
    buckets = get_3x3_bucket_matrix
    puts 'Verifying that distinct columns have the same buckets across all rows'
    assert_equal(buckets[0][0], buckets[1][0])
    assert_equal(buckets[2][0], buckets[1][0])

    assert_equal(buckets[0][1], buckets[1][1])
    assert_equal(buckets[2][1], buckets[1][1])

    assert_equal(buckets[0][2], buckets[1][2])
    assert_equal(buckets[2][2], buckets[1][2])

    3.times {|n| puts "Node #{n} has #{buckets[0][n].size} buckets" }

    puts 'Verifying that there is no overlap of buckets between columns in a row'
    # Since we've already checked column equivalence, this property
    # shall transitively hold across rows (groups).
    # Quick Ruby Set operator reminder; | is union, & is intersection, - is difference
    assert_equal(buckets[0][0] & buckets[0][1], Set.new)
    assert_equal(buckets[0][1] & buckets[0][2], Set.new)

    puts '-------'
    puts 'Testing that content node down has expected data movement'
    puts '-------'
    # Take down relative node 0 in group 1 (absolute distribution key 3).
    # Just set node states instead of actually taking processes down/up
    # since it's quite a bit faster.
    set_content_node_state(3, 'd')

    down_buckets = get_3x3_bucket_matrix(ignore: [3])
    [1, 2].each do |i|
      puts node_bucket_diff(3 + i, buckets[1][i], down_buckets[1][i])
    end
    puts 'Verifying no changes to buckets in groups without nodes down'
    assert_equal(down_buckets[0], buckets[0])
    assert_equal(down_buckets[2], buckets[2])
    puts 'Verifying that remaining nodes in group 1 have taken over data ownership from downed node'
    all_buckets = buckets[0][0] | buckets[0][1] | buckets[0][2]
    assert_equal(down_buckets[1][1] | down_buckets[1][2], all_buckets)
    puts 'Verifying minimal data movement'
    # Should only have gotten _new_ buckets from node 0, should not have moved its own away
    assert_equal(down_buckets[1][1] - buckets[1][0], buckets[1][1])
    assert_equal(down_buckets[1][2] - buckets[1][0], buckets[1][2])

    puts 'Verifying that clients send to correct distributors'
    feed_and_get_all_documents
    set_content_node_state(3, 'u')

    puts 'Verifying that buckets are back in their original locations'
    up_buckets = get_3x3_bucket_matrix
    assert_equal(up_buckets, buckets)

    puts '-------'
    puts 'Testing that node retirement shifts bucket placement away'
    puts '-------'
    # Retirement working "as if" a node has been removed from the config is a
    # double-edged sword, since it allows for functionally replacing a node
    # verbatim without moving data to other nodes. But if no replacement node
    # is added at the same time as retiring and old node, bucket ownership is
    # "shifted" by one.
    # Relative node 1 in group 2 (absolute distribution key 7).
    set_content_node_state(7, 'r')
    retired_buckets = get_3x3_bucket_matrix
    [0, 1, 2].each do |i|
      puts node_bucket_diff(6 + i, buckets[2][i], retired_buckets[2][i])
    end
    puts 'Verifying no bucket movement in unrelated groups'
    assert_equal(retired_buckets[0], buckets[0])
    assert_equal(retired_buckets[1], buckets[1])
    puts 'Verifying buckets have shifted away from the retired node'
    assert_equal(retired_buckets[2][1], Set.new)
    puts 'Verifying retired buckets have found a new home on the other nodes'
    union_buckets = retired_buckets[2][0] | retired_buckets[2][2]
    assert_equal(union_buckets & buckets[2][1], buckets[2][1])
    puts 'Verifying all other buckets are still present'
    assert_equal(union_buckets & buckets[2][0], buckets[2][0])
    assert_equal(union_buckets & buckets[2][2], buckets[2][2])

    puts 'Verifying that clients send to correct distributors'
    feed_and_get_all_documents

    set_content_node_state(7, 'u')
    up_buckets = get_3x3_bucket_matrix
    assert_equal(up_buckets, buckets)

    puts '-------'
    puts 'Testing that maintenance mode does not cause bucket movement'
    puts '-------'

    # Relative node 2 in group 0 (absolute distribution key 2).
    set_content_node_state(2, 'm')
    maintenance_buckets = get_3x3_bucket_matrix
    # This is cheating a tiny bit since the maintenance node is online,
    # so we can fetch its bucket database.
    assert_equal(maintenance_buckets, buckets)

    puts 'Verifying that clients send to correct distributors'
    feed_and_get_all_documents
  end

  def feed_and_get_all_documents
    # Any of these should fail if the container client is unable to send to the correct distributor
    feed_n_buckets(1000)
    get_all_docs
  end

  # Returns a groups*nodes row (group) major matrix
  def get_bucket_matrix(n_groups, n_nodes, ignore)
    buckets = []
    n_groups.times { |group|
      buckets << []
      n_nodes.times { |node|
        node_key = n_groups*group + node
        b = ignore.include?(node_key) ? 0 : get_buckets(node_key)
        buckets[group] << b
      }
    }
    buckets
  end

  def get_3x3_bucket_matrix(ignore: [])
    get_bucket_matrix(3, 3, ignore)
  end

  # Feed n docs so that each fed document is placed into its own distinct bucket.
  # Note that this requires that n < 2^@distribution_bits to avoid super bucket overlap.
  def feed_n_buckets(n)
    assert n > 0
    feed_file = tempfile_name("buckets_feed.json")
    make_feed_file(feed_file, 'music', 0, n - 1, 1)
    feedfile(feed_file, :route => 'storage')
    File.delete(feed_file)
  end

  def get_all_docs
    puts "Getting all docs..."
    1000.times {|i|
      doc = Document.new("id:music:music:n=#{i}:0:system_test")
      doc2 = vespa.document_api_v1.get("id:music:music:n=#{i}:0:system_test", :brief => true)
      assert_equal(doc, doc2)
    }
    puts "Ok. Got all docs."
  end

  def get_buckets(node)
    vespa.storage['storage'].storage[node.to_s].get_buckets['default'].keys.to_set
  end

  def set_content_node_state(idx, state)
    cc = vespa.storage['storage'].get_master_cluster_controller
    cc.set_node_state('storage', 'storage', idx, "s:#{state}")
    vespa.storage['storage'].wait_until_ready(300)
  end

  def node_bucket_diff(node_idx, buckets_before, buckets_after)
    "Node #{node_idx} got #{(buckets_after - buckets_before).size} new buckets, " +
      "removed #{(buckets_before - buckets_after).size} buckets (now has #{buckets_after.size})"
  end

end
