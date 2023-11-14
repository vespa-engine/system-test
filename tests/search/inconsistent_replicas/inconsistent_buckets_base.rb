# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class InconsistentBucketsBase < SearchTest

  def setup
    deploy_app(make_app())
    start
  end

  def make_app(disable_merges: true, enable_condition_probing: true)
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

  def make_replicas_inconsistent_and_contain_incidental_documents_only
    feed_incidental_doc_to_same_bucket # Make sure bucket exists on all nodes
    mark_content_node_down(1)
    feed_another_incidental_doc_to_same_bucket # Document to update does not exist on any replicas
    mark_content_node_up(1)
  end

  # After call, updated_doc_id doc will have
  #  title: 'first title' on node 1
  #  title: 'second title' on node 0
  # Both docs will have artist: 'cool dude'
  def make_replicas_inconsistent_for_single_document
    feed_doc_with_field_value(title: 'first title')
    mark_content_node_down(1)
    feed_doc_with_field_value(title: 'second title')
    mark_content_node_up(1) # Node 1 will have old version of document
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

  def verify_document_is_removed_on_all_nodes
    # Force reading from specific replicas
    mark_content_node_up(0)
    mark_content_node_down(1)
    verify_document_does_not_exist

    mark_content_node_up(1)
    mark_content_node_down(0)
    verify_document_does_not_exist
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

  def update_doc_with_field_value(title:, create_if_missing:, artist: nil, condition: nil)
    update = DocumentUpdate.new('music', updated_doc_id)
    update.addOperation('assign', 'title', title)
    update.addOperation('assign', 'artist', artist) unless artist.nil?
    # Use 'create: true' update to ensure that not performing a write repair as
    # expected will create a document from scratch on the node.
    args = {:create => create_if_missing}
    args[:condition] = condition if condition
    vespa.document_api_v1.update(update, **args)
  end

  def assert_precondition_failure
    begin
      yield
      flunk('Expected TaS failure')
    rescue HttpResponseError => e
      assert_equal(412, e.response_code)
    end
  end

  def teardown
    stop
  end

end
