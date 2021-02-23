# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'doc_generator'

class OutOfSyncReplicasActivationTest < SearchTest

  def setup
    set_owner('vekterli')
    set_description('Test that when we have multiple ready replicas that are out of sync, ' +
                    'we prefer activating the one with the most documents. This may potentially ' +
                    'transiently resurrect old documents whose tombstones have not been merged ' +
                    'over, but that is the case even without this particular heuristic.')
  end

  def make_app(disable_merges:)
    SearchApp.new.sd(SEARCH_DATA+'test.sd').
        elastic.cluster_name("storage").num_parts(2).redundancy(2).
        config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
               add('merge_operations_disabled', disable_merges)).
        enable_http_gateway.
        storage(StorageCluster.new("storage", 2).distribution_bits(8))
  end

  def teardown
    stop
  end
  
  def content_cluster
    vespa.storage['storage']
  end

  def test_prefer_activating_bigger_ready_replica_when_out_of_sync
    deploy_app(make_app(disable_merges: true))
    start

    # Make all docs end up on node 1 which isn't the ideal node when both nodes are up
    set_node_state('storage', 0, 'd')
    set_node_state('distributor', 0, 'd')

    feed_doc_range_to_same_location(1, 10)
    wait_for_hitcount('query=sddocname:test&nocache', 10)

    set_node_state('storage', 0, 'u')
    feed_doc_range_to_same_location(11, 11)
    # Transfer bucket ownership back to distributor 0, wiping any existing transient state.
    set_node_state('distributor', 0, 'u')

    vespa.adminserver.execute('vespa-stat --user 1')

    # Old replica is technically less "ideal" but has more documents and is indexed,
    # so that's the one that should be activated.
    wait_for_hitcount('query=sddocname:test&nocache', 11)
  end

  def set_node_state(type, idx, state)
    content_cluster.get_master_fleet_controller().set_node_state(type, idx, "s:#{state}")
  end

  def feed_doc_range_to_same_location(from_incl, to_incl)
    (from_incl..to_incl).each{|i|
      # Use docs with location-affinity to ensure we put everything into the same bucket
      doc = Document.new('test', "id:test:test:n=1:#{i}")
      doc.add_field('f1', 'foo')
      puts doc.documentid
      vespa.document_api_v1.put(doc, :brief => true)
    }
  end

end
