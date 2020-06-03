# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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

end
