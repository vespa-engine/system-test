# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'doc_generator'

class OutOfSyncReplicasActivationTest < IndexedOnlySearchTest

  def setup
    set_owner('vekterli')
    set_description('Test that when we have multiple ready replicas that are out of sync, ' +
                    'we prefer activating the one with the most documents. This may potentially ' +
                    'transiently resurrect old documents whose tombstones have not been merged ' +
                    'over, but that is the case even without this particular heuristic.')
  end

  def make_app(disable_merges:)
    SearchApp.new.sd(SEARCH_DATA+'test.sd').
        cluster_name("storage").num_parts(2).redundancy(2).
        config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
               add('merge_operations_disabled', disable_merges)).
        enable_document_api.
        storage(StorageCluster.new("storage", 2).distribution_bits(8))
  end

  def teardown
    stop
  end
  
  def content_cluster
    vespa.storage['storage']
  end

  def dump_debug_information
    vespa.adminserver.execute('vespa-stat --user 1')
    content_cluster.distributor.each_value{|n|
      puts "\nDistributor #{n.index}:"
      puts n.get_status_page('/systemstate')
      puts n.get_status_page('/distributor?page=buckets')
    }
    content_cluster.storage.each_value{|n|
      puts "\nContent node #{n.index}:"
      puts n.get_status_page('/systemstate')
      puts n.get_status_page('/bucketdb?showall')
    }
  end

  def test_prefer_activating_bigger_ready_replica_when_out_of_sync
    deploy_app(make_app(disable_merges: true))
    start

    # FIXME temporary
    ['', '2'].each do |n|
      content_cluster.distributor['0'].execute("vespa-logctl distributor#{n}:distributor.operation.idealstate.setactive debug=on,spam=on")
      content_cluster.distributor['0'].execute("vespa-logctl distributor#{n}:distributor.callback.doc.put debug=on,spam=on")
      content_cluster.distributor['0'].execute("vespa-logctl distributor#{n}:pendingclusterstate debug=on,spam=on")
      content_cluster.distributor['0'].execute("vespa-logctl distributor#{n}:pendingbucketspacedbtransition debug=on,spam=on")
      content_cluster.distributor['0'].execute("vespa-logctl searchnode#{n}:storage.bucketdb.manager debug=on,spam=on")
    end

    # Make all docs end up on node 1 which isn't the ideal node when both nodes are up
    set_node_state('storage', 0, 'd')
    set_node_state('distributor', 0, 'd')

    feed_doc_range_to_same_location(1, 10)
    wait_for_hitcount('query=sddocname:test&nocache', 10)

    set_node_state('storage', 0, 'u')
    feed_doc_range_to_same_location(11, 11)
    # Transfer bucket ownership back to distributor 0, wiping any existing transient state.
    set_node_state('distributor', 0, 'u')

    dump_debug_information

    # Old replica is technically less "ideal" but has more documents and is indexed,
    # so that's the one that should be activated.
    begin
      wait_for_hitcount('query=sddocname:test&nocache', 11)
    ensure
      dump_debug_information
    end
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
