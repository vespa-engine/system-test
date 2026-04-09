# Copyright Vespa.ai. All rights reserved.
require 'vds_multi_model_test'
require 'securerandom'

class HierarchDistr < VdsMultiModelTest

  def setup
    set_owner("vekterli")
  end

  def timeout_seconds
    1600
  end

  def tempfile_name(postfix)
    "#{SecureRandom.urlsafe_base64}_#{postfix}"
  end

  def app2
               StorageApp.new.enable_document_api.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
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
               validation_override("redundancy-increase");
  end

  def app3
               StorageApp.new.enable_document_api.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
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
               validation_override("redundancy-increase");
  end

  def app4
               StorageApp.new.enable_document_api.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
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
               validation_override("redundancy-increase");
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
               StorageApp.new.enable_document_api.storage_cluster(
                 StorageCluster.new("storage").
                   redundancy(2).
                   group(NodeGroup.new(0, "mycluster").
                      node(NodeSpec.new("node1", 0)).
                      node(NodeSpec.new("node1", 1)).
                      node(NodeSpec.new("node1", 2)).
                      node(NodeSpec.new("node1", 3)))).
               sd(VDS + "/schemas/music.sd").
               transition_time(0).
               validation_override("redundancy-increase");
  end

  def test_app_change
    @valgrind = false
    deploy_and_wait(app2, true)
    
    feed_file = tempfile_name("1000_buckets_app2.json")
    make_feed_file(feed_file, "music", 0, 999, 1)
    feedfile(feed_file, :route => "storage")

    get_all_docs(true)

    deploy_and_wait(app4)
    vespa.storage["storage"].wait_until_ready(300)

    get_all_docs(true)

    deploy_and_wait(nohierarchy)
    vespa.storage["storage"].wait_until_ready(300)

    get_all_docs(true)

    File.delete(feed_file)
  end

  def test_app2
    deploy_and_wait(app2, true)

    feed_file = tempfile_name("1000_buckets_app2.json")
    make_feed_file(feed_file, "music", 0, 999, 1)
    feedfile(feed_file, :route => "storage")

    get_all_docs(true)

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

    get_all_docs(false)
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_ready(300)

    # all data should still be available
    get_all_docs(true)

    File.delete(feed_file)
  end


  def test_app3
    deploy_and_wait(app3, true)

    feed_file = tempfile_name("1000_buckets_app3.json")
    make_feed_file(feed_file, "music", 0, 999, 1)
    feedfile(feed_file, :route => "storage")

    get_all_docs(true)

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
    get_all_docs(false)
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
    get_all_docs(true)

    File.delete(feed_file)
  end


  def test_app4
    deploy_and_wait(app4, true)

    feed_file = tempfile_name("1000_buckets_app4.json")
    make_feed_file(feed_file, "music", 0, 999, 1)
    feedfile(feed_file, :route => "storage")

    get_all_docs(true)

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
    get_all_docs(false)
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
    get_all_docs(true)

    File.delete(feed_file)
  end


  def get_all_docs(do_assert)
    if do_assert
      puts "Get all docs..."
    end
    begin
      1000.times {|i|
        doc = Document.new("id:music:music:n=#{i}:0:system_test")
        doc2 = vespa.document_api_v1.get("id:music:music:n=#{i}:0:system_test", :brief => true)
        if do_assert
          assert_equal(doc, doc2)
        end
      }
    rescue RuntimeError
      # Ignored
    end
    if do_assert
      puts "Ok. Got all docs."
    end
  end

  def get_buckets(node)
    vespa.storage['storage'].storage[node.to_s].get_buckets['default'].keys.to_set
  end


end
