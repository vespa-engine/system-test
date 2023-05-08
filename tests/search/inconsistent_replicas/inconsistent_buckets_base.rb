# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class InconsistentBucketsBase < SearchTest

  def setup
    deploy_app(make_app())
    start
  end

  def make_app(disable_merges: true, enable_condition_probing: false)
    SearchApp.new.sd(SEARCH_DATA + 'music.sd').
      cluster_name('storage').
      num_parts(2).redundancy(2).ready_copies(2).
      enable_document_api.
      storage(StorageCluster.new('storage', 2).distribution_bits(8)).
      config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
             add('merge_operations_disabled', disable_merges).
             add('enable_condition_probing', enable_condition_probing))
  end

  def updated_doc_id
    'id:storage_test:music:n=1:foo'
  end

  def feed_doc_with_field_value(title:)
    # Also add a second field that updates won't touch so that we can detect if
    # a 'create: true' update erroneously resets the state on any replica.
    doc = Document.new('music', updated_doc_id).
        add_field('title', title).
        add_field('artist', 'cool dude')
    vespa.document_api_v1.put(doc)
  end

  def remove_document
    vespa.document_api_v1.remove(updated_doc_id)
  end

  def content_cluster
    vespa.storage['storage']
  end

  def mark_node_in_state(idx, state)
    content_cluster.get_master_fleet_controller().set_node_state('storage', idx, "s:#{state}");
  end

  def mark_content_node_down(idx)
    mark_node_in_state(idx, 'd')
  end

  def mark_content_node_up(idx)
    mark_node_in_state(idx, 'u')
  end

  def verify_document_does_not_exist
    doc = vespa.document_api_v1.get(updated_doc_id)
    assert_equal(nil, doc)
  end

  def update_doc_with_field_value(title:, create_if_missing:, artist: nil)
    update = DocumentUpdate.new('music', updated_doc_id)
    update.addOperation('assign', 'title', title)
    update.addOperation('assign', 'artist', artist) unless artist.nil?
    # Use 'create: true' update to ensure that not performing a write repair as
    # expected will create a document from scratch on the node.
    vespa.document_api_v1.update(update, :create => create_if_missing)
  end

  def teardown
    stop
  end

end
