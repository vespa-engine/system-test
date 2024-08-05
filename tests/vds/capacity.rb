# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class Capacity < VdsTest

  def setup
    @valgrind=false
    set_owner("vekterli")
  end

  def test_capacity
    deploy_app(
               StorageApp.new.
               enable_document_api.
               storage_cluster(
                 StorageCluster.new("storage").
                   group(NodeGroup.new(0, "mygroup").
                     node(NodeSpec.new("node1", 0, :capacity => 2.0)).
                     node(NodeSpec.new("node1", 1)))).
               sd(VDS + "/schemas/music.sd").
               transition_time(0));
    start

    # Initial config: .0.c:2.0 and .1.c:1.0
    vespa.storage["storage"].storage["0"].wait_for_current_node_capacity(2.0)
    vespa.storage["storage"].storage["1"].wait_for_current_node_capacity(1.0)

    # Feed documents to generate 100 buckets
    100.times{|i|
      doc = Document.new("music", "id:storage_test:music:n=#{i}:doc")
      vespa.document_api_v1.put(doc)
    }

    # collect buckets created on each nodes
    num_buckets_0 = vespa.storage['storage'].storage['0'].get_bucket_count
    num_buckets_1 = vespa.storage['storage'].storage['1'].get_bucket_count

    # allow for 10% skew
    assert( (num_buckets_0.to_i - 2*num_buckets_1.to_i).abs < 10 )

    # Change config: .0.c:1.0 and .1.c:3.0
    deploy_app(
               StorageApp.new.
               enable_document_api.
               storage_cluster(
                 StorageCluster.new("storage").
                   group(NodeGroup.new(0, "mygroup").
                     node(NodeSpec.new("node1", 0)).
                     node(NodeSpec.new("node1", 1, :capacity => 3.0)))).
               sd(VDS + "/schemas/music.sd").
               transition_time(0));

    vespa.storage["storage"].storage["0"].wait_for_current_node_capacity(1.0)
    vespa.storage["storage"].storage["1"].wait_for_current_node_capacity(3.0)
    vespa.storage["storage"].wait_until_ready

    # collect buckets moved on each nodes
    num_buckets_0 = vespa.storage['storage'].storage['0'].get_bucket_count
    num_buckets_1 = vespa.storage['storage'].storage['1'].get_bucket_count

    # allow for 10% skew
    assert( (num_buckets_1.to_i - 3*num_buckets_0.to_i).abs < 10 )
  end

  def teardown
    stop
  end
end



