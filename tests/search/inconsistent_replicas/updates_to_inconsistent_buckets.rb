# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'inconsistent_buckets_base'

class UpdatesToInconsistentBucketsTest < InconsistentBucketsBase

  def setup
    set_owner('vekterli')
    super
  end

  def maybe_enable_debug_logging(enable)
    return unless enable
    ['', '2'].each do |d|
      vespa.adminserver.execute("vespa-logctl distributor#{d}:distributor.operations.external.two_phase_update debug=on,spam=on")
      vespa.adminserver.execute("vespa-logctl distributor#{d}:distributor.operations.external.get debug=on,spam=on")
      vespa.adminserver.execute("vespa-logctl distributor#{d}:distributor.operations.external.update debug=on,spam=on")
    end
  end

  def do_test_updates_with_divergent_document_versions_are_write_repaired(create_if_missing:)
    set_description('Test that updates trigger write-repair when documents across ' +
                    'replicas have diverging timestamps')

    make_replicas_inconsistent_for_single_document
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

  def do_test_conditional_update_with_divergent_document_versions(create_if_missing:, condition:, expect_tas_failure:)
    set_description('Test that conditional updates trigger write-repair when documents across ' +
                    'replicas have diverging timestamps')

    make_replicas_inconsistent_for_single_document

    begin
      update_doc_with_field_value(title: 'third title', create_if_missing: create_if_missing, condition: condition)
      flunk('Should have failed with TaS failure, but operation succeeded') if expect_tas_failure
    rescue HttpResponseError => e
      assert_equal(412, e.response_code)
      flunk('Did not expect to fail with TaS failure') unless expect_tas_failure
    end

    expected_title = expect_tas_failure ? 'second title' : 'third title'

    # If we expect a failure, nothing should happen in the cluster and the documents will remain untouched (and out of sync).
    # Otherwise, we expect both nodes to be forcefully converged to the same state.
    if expect_tas_failure
      verify_document_has_expected_contents(title: expected_title) # Just checks newest version
    else
      verify_document_has_expected_contents_on_all_nodes(title: expected_title)
    end
  end

  def test_matching_conditional_update_with_divergent_document_versions_is_applied
    do_test_conditional_update_with_divergent_document_versions(
            create_if_missing: false,
            condition: 'music.title=="second title"', # Matches newest document version
            expect_tas_failure: false)
  end

  def test_mismatching_conditional_update_with_divergent_document_versions_is_not_applied
    do_test_conditional_update_with_divergent_document_versions(
            create_if_missing: false,
            condition: 'music.title=="first title"', # Matches oldest, but _not_ newest document version
            expect_tas_failure: true)
  end

  def test_mismatching_conditional_update_with_divergent_document_version_ignores_auto_create
    # Sanity check that auto-create does not somehow override condition mismatch during write-repair
    do_test_conditional_update_with_divergent_document_versions(
            create_if_missing: true,
            condition: 'music.title=="first title"',
            expect_tas_failure: true)
  end

end
