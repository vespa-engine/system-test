# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'inconsistent_buckets_base'

class InconsistentConditionalPutTest < InconsistentBucketsBase

  def setup
    set_owner('vekterli')
    super
  end 

  def put_with_condition(title:, condition:, create: false)
    doc = Document.new('music', updated_doc_id).
        add_field('title', title).
        add_field('artist', 'cool dude')
    vespa.document_api_v1.put(doc, :condition => condition, :create => create)
  end

  def do_test_conditional_put_matching_existing_doc_is_applied(create:)
    set_description('Test that conditional Put is applied when document versions are inconsistent ' +
                    'across replicas and the condition _matches_ the newest document')

    make_replicas_inconsistent_for_single_document

    put_with_condition(title: 'cool stuff', condition: 'music.title == "second title"', create: create)
    verify_document_has_expected_contents_on_all_nodes(title: 'cool stuff')
  end

  def test_conditional_put_matching_existing_doc_is_applied
    do_test_conditional_put_matching_existing_doc_is_applied(create: false)
  end

  def test_conditional_put_matching_existing_doc_is_applied_and_setting_create_is_no_op
    do_test_conditional_put_matching_existing_doc_is_applied(create: true) # Should not change anything
  end

  def do_test_conditional_put_mismatching_existing_doc_is_not_applied(create:)
    set_description('Test that conditional Put is NOT applied when document versions are inconsistent ' +
                    'across replicas and the condition _does not match_ the newest document')

    make_replicas_inconsistent_for_single_document

    assert_precondition_failure {
      put_with_condition(title: 'cool stuff', condition: 'music.title == "first title"', create: create)
    }
    verify_document_has_expected_contents(title: 'second title') # Just checks newest version
  end

  def test_conditional_put_mismatching_existing_doc_is_not_applied
    do_test_conditional_put_mismatching_existing_doc_is_not_applied(create: false)
  end

  def test_conditional_put_with_create_mismatching_existing_doc_is_not_applied
    do_test_conditional_put_mismatching_existing_doc_is_not_applied(create: true) # Should not change anything
  end

  def test_conditional_put_with_create_is_unconditionally_applied_when_newest_document_version_is_tombstone
    set_description('Test that conditional Put with create:true is unconditionally applied when the ' +
                    'newest document version is a tombstone')

    feed_doc_with_field_value(title: 'first title')
    mark_content_node_down(1)
    remove_document
    mark_content_node_up(1)

    put_with_condition(title: 'cool stuff', condition: 'music.title == "not matching"', create: true)
    verify_document_has_expected_contents_on_all_nodes(title: 'cool stuff')
  end

  def test_conditional_put_with_create_is_unconditionally_applied_when_document_does_not_exist
    set_description('Test that conditional Put with create:true is unconditionally applied when the ' +
                    'document does not exist across any inconsistent replicas')

    make_replicas_inconsistent_and_contain_incidental_documents_only

    put_with_condition(title: 'cool stuff', condition: 'music.title == "not matching"', create: true)
    verify_document_has_expected_contents_on_all_nodes(title: 'cool stuff')
  end

  def test_conditional_put_without_create_is_not_applied_when_document_does_not_exist
    set_description('Test that conditional Put with create:false is NOT applied when the ' +
                    'document does not exist across any inconsistent replicas')

    make_replicas_inconsistent_and_contain_incidental_documents_only
    # TODO change semantics for Not Found...
    assert_precondition_failure {
      put_with_condition(title: 'cool stuff', condition: 'music.title == "not matching"', create: false)
    }
    verify_document_does_not_exist
  end

end
