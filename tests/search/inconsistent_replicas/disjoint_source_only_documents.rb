# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'doc_generator'

class DisjointSourceOnlyDocuments < SearchTest

  def make_app(disable_merges:)
    SearchApp.new.sd(selfdir + 'test.sd').
        config(ConfigOverride.new('vespa.config.content.stor-filestor').
               add('bucket_merge_chunk_size', 1024)). # Enforce triggering chunk limit edge case
        config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
               add('merge_operations_disabled', disable_merges)).
        enable_document_api.
        search_type("ELASTIC").cluster_name("storage").num_parts(3).redundancy(1).
        storage(StorageCluster.new("storage", 3).distribution_bits(8))
  end

  def setup
    set_owner('vekterli')
    deploy_app(make_app(disable_merges: true))
    @debug_log_enabled = false
    start
  end

  def teardown
    stop
  end

  def test_chunked_merge_diffing_works_with_disjoint_source_only_document_sets
    set_description('Test that merge protocol correctly handles edge case where ' +
                    'multiple source-only replicas are present and completing the merge ' +
                    'must happen in multiple passes due to chunk size limits')

    set_content_node_state(1, 'd')
    set_content_node_state(2, 'd')
    # Node 0 is only node Up at this point

    puts 'Feeding 30 disjoint docs, 10 docs on each node'
    n_docs = 30
    feed_doc_range_to_same_location(1, 10)
    set_content_node_state(0, 'd')
    set_content_node_state(1, 'u')
    feed_doc_range_to_same_location(11, 20)
    set_content_node_state(1, 'd')
    set_content_node_state(2, 'u')
    feed_doc_range_to_same_location(21, 30)

    puts 'Marking all nodes except 0 as retired'
    enable_merge_debug_logging if @debug_log_enabled

    set_content_node_state(0, 'u')
    set_content_node_state(1, 'r')
    set_content_node_state(2, 'r')

    gen = get_generation(deploy_app(make_app(disable_merges: false)))
    # Ensure that config is visible on nodes (and triggering ideal state ops) before running wait_until_ready
    cluster.wait_until_content_nodes_have_config_generation(gen.to_i)
    cluster.wait_until_ready(200)

    puts "Checking that cluster contains #{n_docs} docs..."
    actual = cluster.get_document_count
    if actual != n_docs
      puts 'Document count mismatch, dumping actual document set:'
      vespa.adminserver.execute('vespa-visit -i | sort')
      flunk "Expected #{n_docs} documents, got #{actual}"
    end
  end

  def feed_doc_range_to_same_location(from_incl, to_incl)
    (from_incl..to_incl).each{|i|
      # Use docs with location-affinity to ensure we put everything into the same bucket
      doc = Document.new('test', "id:test:test:n=1:#{i}")
      # Add some uncompressable document data to ensure we will trivially exceed configured merge chunk size
      doc.add_field('title', StringGenerator.rand_string(500, 600))
      puts doc.documentid
      vespa.document_api_v1.put(doc, :brief => true)
    }
  end

  def cluster
    vespa.storage['storage']
  end

  def set_content_node_state(idx, state)
    cluster.get_master_fleet_controller().set_node_state('storage', idx, "s:#{state}")
  end

  def enable_merge_debug_logging
    # Only works for host-local debugging
    ['', '2', '3'].each do |n|
      vespa.adminserver.execute("vespa-logctl searchnode#{n}:persistence.mergehandler debug=on,spam=on")
      vespa.adminserver.execute("vespa-logctl distributor#{n}:distributor.operation.idealstate.merge debug=on,spam=on")
    end
  end

end

