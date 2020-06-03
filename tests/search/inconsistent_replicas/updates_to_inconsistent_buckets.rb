# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'inconsistent_buckets_base'

class UpdatesToInconsistentBucketsTest < InconsistentBucketsBase

  def setup
    set_owner('vekterli')
    super
  end

  def maybe_enable_debug_logging(enable)
    return if not enable
    ['', '2'].each do |d|
      vespa.adminserver.execute("vespa-logctl distributor#{d}:distributor.callback.twophaseupdate debug=on,spam=on")
      vespa.adminserver.execute("vespa-logctl distributor#{d}:distributor.callback.doc.get debug=on,spam=on")
      vespa.adminserver.execute("vespa-logctl distributor#{d}:distributor.callback.doc.update debug=on,spam=on")
    end
  end

  def incidental_doc_id
    'id:storage_test:music:n=1:bar' # Must be in same location as updated_doc_id
  end

  def another_incidental_doc_id
    'id:storage_test:music:n=1:baz' # Must be in same location as updated_doc_id
  end

  def feed_incidental_doc_to_same_bucket
    doc = Document.new('music', incidental_doc_id).add_field('title', 'hello world')
    vespa.document_api_v1.put(doc)
  end

  def feed_another_incidental_doc_to_same_bucket
    doc = Document.new('music', another_incidental_doc_id).add_field('title', 'hello moon')
    vespa.document_api_v1.put(doc)
  end

  def update_doc_with_field_value(title:, create_if_missing:, artist: nil)
    update = DocumentUpdate.new('music', updated_doc_id)
    update.addOperation('assign', 'title', title)
    update.addOperation('assign', 'artist', artist) unless artist.nil?
    # Use 'create: true' update to ensure that not performing a write repair as
    # expected will create a document from scratch on the node.
    vespa.document_api_v1.update(update, :create => create_if_missing)
  end


  def wait_until_no_pending_merges
    content_cluster.wait_until_ready
  end

  def verify_document_has_expected_contents(title:)
    fields = vespa.document_api_v1.get(updated_doc_id).fields
    assert_equal(title, fields['title'])
    # Existing field must have been preserved
    assert_equal('cool dude', fields['artist'])
  end

  def dump_bucket_contents
    vespa.adminserver.execute("vespa-stat --document #{updated_doc_id} --dump")
  end

  def puts_decorated(str)
    puts '--------'
    puts str
    puts '--------'
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

  def make_replicas_inconsistent_and_contain_incidental_documents_only
    feed_incidental_doc_to_same_bucket # Make sure bucket exists on all nodes
    mark_content_node_down(1)
    feed_another_incidental_doc_to_same_bucket # Document to update does not exist on any replicas
    mark_content_node_up(1)
  end

  def test_create_if_missing_update_succeeds_if_no_existing_document_on_any_replicas
    make_replicas_inconsistent_and_contain_incidental_documents_only
    update_doc_with_field_value(title: 'really neat title', artist: 'cool dude', create_if_missing: true)

    verify_document_has_expected_contents_on_all_nodes(title: 'really neat title')
  end

  def test_non_create_if_missing_update_fails_if_no_existing_document_on_any_replicas
    make_replicas_inconsistent_and_contain_incidental_documents_only
    update_doc_with_field_value(title: 'really neat title', create_if_missing: false)

    verify_document_does_not_exist
  end

  def test_deleted_document_not_resurrected_by_update
    set_description('Test that tombstone only present on a subset of replicas ' +
                    'is taken into account during Update write-repair')

    feed_doc_with_field_value(title: 'first title')
    mark_content_node_down(1)
    remove_document
    mark_content_node_up(1)

    update_doc_with_field_value(title: 'uh oh', create_if_missing: false)
    verify_document_does_not_exist
  end

  def test_document_delete_visibility_for_updates_is_propagated_through_merges
    set_description('Tests that partial updates with create: false do not create new ' +
                    'document versions when a tombstone for the document ID in question ' +
                    'shall have been merged from another replica prior to the operation')

    puts_decorated 'Feeding initial document'
    feed_doc_with_field_value(title: 'first title')
    dump_bucket_contents

    puts_decorated 'Taking down node 1 and removing document with single replica present'
    mark_content_node_down(1)
    remove_document
    dump_bucket_contents

    puts_decorated 'Unblocking merges to allow remove-entries to be merged'
    deploy_app(make_app(three_phase_updates: @params[:enable_3phase],
                        fast_restart: @params[:fast_restart],
                        disable_merges: false))

    puts_decorated 'Taking node 1 back up'
    mark_content_node_up(1)
    wait_until_no_pending_merges
    dump_bucket_contents

    puts_decorated 'Node 1 back up and all merges have completed. Taking node 0 down'
    mark_content_node_down(0)
    puts_decorated 'Verifying update does not operate on old document version'
    update_doc_with_field_value(title: 'uh oh', create_if_missing: false)
    dump_bucket_contents
    verify_document_does_not_exist

    puts_decorated 'Taking node 0 back up to verify remove-entry is visible'
    mark_content_node_up(0)
    dump_bucket_contents
    wait_until_no_pending_merges
    verify_document_does_not_exist
  end

end

