# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
    vespa.storage["storage"].wait_until_cluster_up # TODO: Is this necessary?
    feedfile(feed_file, :route => "storage")

    vespagetAllDocs(true)

    deploy_and_wait(app4)

    vespa.storage["storage"].wait_until_ready(300)

    vespagetAllDocs(true)

    deploy_and_wait(nohierarchy)

    vespa.storage["storage"].wait_until_ready(300)

    vespagetAllDocs(true)

    File.delete(feed_file)
  end

  def test_app2
    deploy_and_wait(app2, true)

    feed_file = tempfile_name("1000_buckets_app2.json")
    make_feed_file(feed_file, "music", 0, 999, 1)
    vespa.storage["storage"].wait_until_cluster_up # TODO: Is this necessary?
    feedfile(feed_file, :route => "storage")

    vespagetAllDocs(true)

    set0=getBuckets(0)
    set1=getBuckets(1)
    set2=getBuckets(2)
    set3=getBuckets(3)

    # no overlapp within switches
    assert(set0.intersection(set1).empty?)
    assert(set2.intersection(set3).empty?)

    # full overlapp between switches
    assert(set0.union(set1) == set2.union(set3))

    # should have cross-switch overlapp
    assert(!set0.intersection(set2).empty?)
    assert(!set0.intersection(set3).empty?)
    assert(!set1.intersection(set2).empty?)
    assert(!set1.intersection(set3).empty?)

    # take down switch 0
    vespa.stop_content_node('storage', 0)
    vespa.stop_content_node('storage', 1)

    vespagetAllDocs(false)
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_cluster_up # TODO: Is this necessary?
    vespa.storage["storage"].wait_until_ready(300)

    # all data should still be available
    vespagetAllDocs(true)

    File.delete(feed_file)
  end


  def test_app3
    deploy_and_wait(app3, true)

    feed_file = tempfile_name("1000_buckets_app3.json")
    make_feed_file(feed_file, "music", 0, 999, 1)
    vespa.storage["storage"].wait_until_cluster_up # TODO: Is this necessary?
    feedfile(feed_file, :route => "storage")

    vespagetAllDocs(true)

    set0=getBuckets(0)
    set1=getBuckets(1)
    set2=getBuckets(2)
    set3=getBuckets(3)
    set4=getBuckets(4)

    # should have full overlap within switch 1
    assert(set3 == set4)

    # should not have full overlap within switch 0
    assert(set0 != set1)
    assert(set0 != set2)
    assert(set1 != set2)

    # should have no overlap between switches
    set012=set0.union(set1).union(set2)
    set34=set3.union(set4)
    assert(set012.intersection(set34).empty?)

    # take down node 0 in switch 0
    vespa.stop_content_node('storage', 0)
    vespagetAllDocs(false)
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_cluster_up # TODO: Is this necessary?
    vespa.storage["storage"].wait_until_ready(300)

    set1new=getBuckets(1)
    set2new=getBuckets(2)
    set3new=getBuckets(3)
    set4new=getBuckets(4)

    # data redistribution should happen only within switch 0
    assert(set1new != set1)
    assert(set2new != set2)
    assert(set3new == set3)
    assert(set4new == set4)

    # should have recovered all data
    set12new=set1.union(set2)
    assert(set12new == set012)

    # all data should still be available
    vespagetAllDocs(true)

    File.delete(feed_file)
  end


  def test_app4
    deploy_and_wait(app4, true)

    feed_file = tempfile_name("1000_buckets_app4.json")
    make_feed_file(feed_file, "music", 0, 999, 1)
    vespa.storage["storage"].wait_until_cluster_up # TODO: Is this necessary?
    feedfile(feed_file, :route => "storage")

    vespagetAllDocs(true)

    set0=getBuckets(0)
    set1=getBuckets(1)
    set2=getBuckets(2)
    set3=getBuckets(3)

    # should not have overlap within racks
    assert(set0.intersection(set1).empty?)
    assert(set2.intersection(set3).empty?)

    # should have cross-switch overlapp
    assert(!set0.intersection(set2).empty?)
    assert(!set0.intersection(set3).empty?)
    assert(!set1.intersection(set2).empty?)
    assert(!set1.intersection(set3).empty?)

    # should have full overlap between switches
    set01=set0.union(set1)
    set23=set2.union(set3)
    assert(set01 == set23)

    # take down node 0 in switch 0 rack 0
    vespa.stop_content_node('storage', 0)
    vespagetAllDocs(false)
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_cluster_up # TODO: Is this necessary?
    vespa.storage["storage"].wait_until_ready(300)

    set1new=getBuckets(1)
    set2new=getBuckets(2)
    set3new=getBuckets(3)

    # no data should be redistributed
    assert(set1new == set1)
    assert(set2new == set2)
    assert(set3new == set3)

    # all data should still be available
    vespagetAllDocs(true)

    File.delete(feed_file)
  end


  def vespagetAllDocs(doAssert)
    if doAssert == true
      puts "Get all docs..."
    end
    begin
      1000.times {|i|
        doc = Document.new("music", "id:music:music:n=#{i}:0:system_test")
        doc2 = vespa.document_api_v1.get("id:music:music:n=#{i}:0:system_test")
        if doAssert == true
          assert_equal(doc, doc2)
        end
      }
    rescue RuntimeError => exc
    end
    if doAssert == true
      puts "Ok. Got all docs."
    end
  end

  def getBuckets(node)
    return vespa.storage['storage'].storage[node.to_s].get_buckets()['default'].keys.to_set
  end

  def teardown
      stop
  end

end
