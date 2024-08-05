# Copyright Vespa.ai. All rights reserved.
require_relative 'inconsistent_buckets_base'

class VisibilityForDeletedDocumentsInInconsistentBucketsTest < InconsistentBucketsBase

  def setup
    super
    set_owner('vekterli')
  end

  def test_deleted_document_not_visible_by_get_when_replicas_inconsistent
    set_description('Test that tombstone only present on a subset of replicas ' +
                    'is taken into account during Get read-repair')

    feed_doc_with_field_value(title: 'first title')
    mark_content_node_down(1)
    remove_document
    mark_content_node_up(1)

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
    gen = get_generation(deploy_app(make_app(disable_merges: false)))
    # Ensure that config is visible on nodes (and triggering ideal state ops) before running wait_until_ready
    content_cluster.wait_until_content_nodes_have_config_generation(gen.to_i)

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

  def dump_bucket_contents
    vespa.adminserver.execute("vespa-stat --document #{updated_doc_id} --dump")
  end

  def puts_decorated(str)
    puts '--------'
    puts str
    puts '--------'
  end

  def wait_until_no_pending_merges
    content_cluster.wait_until_ready
  end

end
