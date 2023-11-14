# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class DistributorDown < VdsTest

  def cluster
    vespa.storage['storage']
  end

  def stop_distributor(idx)
    cluster.distributor[idx.to_s].stop
  end

  def start_distributor(idx)
    cluster.distributor[idx.to_s].start
    cluster.distributor[idx.to_s].wait_for_current_node_state('u')
  end

  def test_distributordown
    set_owner("vekterli")
    deploy_app(default_app)
    start

    stop_distributor(0)

    begin
      doc = Document.new("music", "id:storage_test:music:n=1234:u")
      vespa.document_api_v1.put(doc)
      assert(false)
    rescue RuntimeError => exc
    end

    start_distributor(0)

    doc = Document.new("music", "id:storage_test:music:n=1234:u")
    vespa.document_api_v1.put(doc)
  end

  def feedDocs(numdocs = 20)
    numdocs.times{|i|
      doc = Document.new("music", "id:storage_test:music:n=#{i}:u")
      vespa.document_api_v1.put(doc)
    }
  end

  def verifyDocumentCountOnDistributor(index, expected, timeout=120)
    time_started = Time.now
    while Time.now - time_started < timeout
      actual = cluster.distributor[index.to_s].get_numdoc_stored
      puts "Got #{actual} documents from distributor metrics"
      return if expected == actual
      sleep 5
    end
    raise ("Timed out after #{timeout} seconds while waiting for #{expected} " +
           "docs to be reported by distributor #{index}")
  end

  def create_app
    StorageApp.new.enable_document_api.storage_cluster(
              StorageCluster.new("storage").
              redundancy(2).
              group(NodeGroup.new(0, "mycluster").
                  distribution("1|*").
                  group(
                      NodeGroup.new(0, "switch0").
                      node(NodeSpec.new("node1", 0))).
                  group(
                      NodeGroup.new(1, "switch1").
                      node(NodeSpec.new("node1", 1))))).
      sd(VDS + "/schemas/music.sd").
      transition_time(0)
  end

  def test_all_distributors_in_one_group_down
    set_owner("vekterli")
    deploy_app(create_app)
    start

    puts "Feed through both distributors. Validate buckets on both."
    feedDocs()
    verifyDocumentCountOnDistributor(0, 8)
    verifyDocumentCountOnDistributor(1, 12)

    puts "Take down one distributor. Refeed. All buckets on one."
    stop_distributor(0)
    cluster.wait_until_ready(120, ['0']) # Distributor blocklist
    verifyDocumentCountOnDistributor(1, 20)

    puts "Take distributor back up. Refeed. Buckets on both again."
    start_distributor(0)
    cluster.wait_until_ready
    verifyDocumentCountOnDistributor(0, 8)
    verifyDocumentCountOnDistributor(1, 12)
  end

  def teardown
    stop
  end
end

