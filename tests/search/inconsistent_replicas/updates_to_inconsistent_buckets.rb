# Copyright 2020 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class UpdatesToInconsistentBucketsTest < SearchTest

  def setup
    set_owner('vekterli')
    deploy_app(make_app())
    start
  end

  def teardown
    stop
  end

  def make_app
    SearchApp.new.sd(SEARCH_DATA + 'music.sd').
      cluster_name('storage').
      num_parts(2).redundancy(2).ready_copies(2).
      enable_http_gateway.
      storage(StorageCluster.new('storage', 2).distribution_bits(8)).
      config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
             add('merge_operations_disabled', true).
             add('restart_with_fast_update_path_if_all_get_timestamps_are_consistent', true))
  end

  def updated_doc_id
    'id:storage_test:music:n=1:foo'
  end

  def incidental_doc_id
    'id:storage_test:music:n=1:bar' # Must be in same location as updated_doc_id
  end

  def feed_doc_with_field_value(title:)
    # Also add a second field that updates won't touch so that we can detect if
    # a 'create: true' update erroneously resets the state on any replica.
    doc = Document.new('music', updated_doc_id).
        add_field('title', title).
        add_field('artist', 'cool dude')
    vespa.document_api_v1.put(doc)
  end

  def feed_incidental_doc_to_same_bucket
    doc = Document.new('music', incidental_doc_id).add_field('title', 'hello world')
    vespa.document_api_v1.put(doc)
  end

  def update_doc_with_field_value(title:, create_if_missing:)
    update = DocumentUpdate.new('music', updated_doc_id)
    update.addOperation('assign', 'title', title)
    # Use 'create: true' update to ensure that not performing a write repair as
    # expected will create a document from scratch on the node.
    vespa.document_api_v1.update(update, :create => create_if_missing)
  end

  def mark_node_in_state(idx, state)
    vespa.storage['storage'].get_master_fleet_controller().set_node_state('storage', idx, "s:#{state}");
  end

  def mark_content_node_down(idx)
    mark_node_in_state(idx, 'd')
  end

  def mark_content_node_up(idx)
    mark_node_in_state(idx, 'u')
  end

  def verify_document_has_expected_contents(title:)
    fields = vespa.document_api_v1.get(updated_doc_id).fields
    assert_equal(title, fields['title'])
    # Existing field must have been preserved
    assert_equal('cool dude', fields['artist'])
  end

  def verify_document_has_expected_contents_on_all_nodes(title:)
    # Force reading from specific replicas
    mark_content_node_up(0)
    mark_content_node_down(1)
    verify_document_has_expected_contents(title: title)

    mark_content_node_up(1)
    mark_content_node_down(0)
    verify_document_has_expected_contents(title: title)
  end

  def do_test_updates_with_divergent_document_versions_are_write_repaired(create_if_missing:)
    set_description('Test that updates trigger write-repair when documents across ' +
                    'replicas have diverging timestamps')

    feed_doc_with_field_value(title: 'first title')
    mark_content_node_down(1)
    feed_doc_with_field_value(title: 'second title')
    mark_content_node_up(1) # Node 1 will have old version of document
    update_doc_with_field_value(title: 'third title', create_if_missing: create_if_missing)

    verify_document_has_expected_contents_on_all_nodes(title: 'third title')
  end

  def test_updates_with_divergent_document_versions_are_write_repaired_with_create_false
    do_test_updates_with_divergent_document_versions_are_write_repaired(create_if_missing: false)
  end

  def test_updates_with_divergent_document_versions_are_write_repaired_with_create_true
    do_test_updates_with_divergent_document_versions_are_write_repaired(create_if_missing: true)
  end

  def do_test_updates_with_document_missing_in_single_replica_are_write_repaired(create_if_missing:)
    set_description('Test that updates trigger write-repair when the document is entirely missing in a replica')

    feed_incidental_doc_to_same_bucket # Make sure bucket exists on all nodes
    mark_content_node_down(1)
    feed_doc_with_field_value(title: 'first title')
    mark_content_node_up(1) # Node 1 will not have the document
    update_doc_with_field_value(title: 'second title', create_if_missing: create_if_missing)

    verify_document_has_expected_contents_on_all_nodes(title: 'second title')
  end

  def test_updates_with_document_missing_in_single_replica_are_write_repaired_create_false
    do_test_updates_with_document_missing_in_single_replica_are_write_repaired(create_if_missing: false)
  end

  def test_updates_with_document_missing_in_single_replica_are_write_repaired_create_true
    do_test_updates_with_document_missing_in_single_replica_are_write_repaired(create_if_missing: true)
  end

end

