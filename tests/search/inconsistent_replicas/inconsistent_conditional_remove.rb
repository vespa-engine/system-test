# Copyright Vespa.ai. All rights reserved.
require_relative 'inconsistent_buckets_base'

class InconsistentConditionalRemoveTest < InconsistentBucketsBase

  def setup
    set_owner('vekterli')
    super
  end

  def remove_with_condition(condition)
    vespa.document_api_v1.remove(updated_doc_id, :condition => condition)
  end

  def test_conditional_remove_matching_existing_doc_is_applied
    set_description('Test that conditional Remove is applied when document versions are inconsistent ' +
                    'across replicas and the condition _matches_ the newest document')
    make_replicas_inconsistent_for_single_document
    remove_with_condition('music.title == "second title"') # Newest doc version
    verify_document_is_removed_on_all_nodes
  end

  def test_conditional_remove_mismatching_existing_doc_is_not_applied
    set_description('Test that conditional Remove is NOT applied when document versions are inconsistent ' +
                    'across replicas and the condition _does not match_ the newest document')
    make_replicas_inconsistent_for_single_document
    assert_precondition_failure {
      remove_with_condition('music.title == "first title"')
    }
    verify_document_has_expected_contents(title: 'second title') # Just checks newest version
  end

  def test_conditional_remove_of_non_existent_document_in_inconsistent_bucket
    set_description('condition probe decides that the document does not exist, ' +
                    'this makes the remove fail with precondition failure')
    make_replicas_inconsistent_and_contain_incidental_documents_only
    assert_precondition_failure {
      remove_with_condition('true')
    }
  end

end
