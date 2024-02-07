# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class ImportedFieldsInSelectionsTest < IndexedOnlySearchTest

  def setup
    set_owner('vekterli')
    @data_dir = selfdir + 'grandparent_search/'
  end

  def teardown
    stop
  end

  def gc_interval_secs
    2
  end

  def make_app(with_gc:, searchable_copies: 1)
    if with_gc
      n_nodes = redundancy = 3
      ready_copies = searchable_copies
      # Preserves documents that either have an invalid grandparent, or the grandparent has a1 in {5, 6}
      selection = 'child.a1 == null or (child.a1 == 5 or child.a1 == 6)'
    else
      n_nodes = redundancy = ready_copies = 1
      selection = nil
    end

    app = SearchApp.new.
        sd(@data_dir + "grandparent.sd", { :global => true }).
        sd(@data_dir + "parent.sd", { :global => true }).
        sd(@data_dir + "child.sd", { :selection => selection }).
        cluster_name('storage').
        garbagecollection(with_gc).
        garbagecollectioninterval(gc_interval_secs).
        enable_document_api.
        num_parts(n_nodes).redundancy(redundancy).ready_copies(ready_copies).
        storage(StorageCluster.new('storage', n_nodes).distribution_bits(8))
    app
  end

  def enumerate_docs_matching(selection, bucket_space = 'default')
    # We have far less than 1k docs, so wanted doc count is just to ensure we fetch everything in one request.
    out = vespa.document_api_v1.visit(:cluster => 'storage', :selection => selection,
                                      :bucketSpace => bucket_space, :wantedDocumentCount => 1000)
    out['documents'].map{|d| d['id']}.sort.to_a
  end

  #
  # The documents fed have the following references:
  #
  #   id:test:child::0  -+
  #   (a3=100)           |
  #                      |-----> id:test:parent::0  --+--> id:test:grandparent::0
  #                      |       (a2=10)              |    (a1=5)
  #   id:test:child::4  -+                            |
  #   (a3=104)                                        |
  #                                                   |
  #   id:test:child::3  -------> id:test:parent::3  --+
  #   (a3=103)                   (a2=13)
  #
  #   id:test:child::1  -+
  #   (a3=101)           |
  #                      |-----> id:test:parent::1  -----> id:test:grandparent::1
  #                      |        (a2=11)                  (a1=6)
  #   id:test:child::5  -+
  #   (a3=105)
  #
  #   id:test:child::2  -------> id:test:parent::2  -----> id:test:grandparent::2 (non-existing)
  #   (a3=102)                   (a2=12)                   (a1=N/A)
  #
  def feed_docs_with_references
    feed(:file => @data_dir + "feed-0.json")
  end

  def test_imported_fields_can_be_used_in_visitor_document_selections
    set_description('Test that imported parent+grandparent fields can be used in ' +
                    'document selections for user-facing visitor operations')

    deploy_app(make_app(with_gc: false))
    start

    feed_docs_with_references

    assert_equal(['id:test:child::1', 'id:test:child::5'],
                 enumerate_docs_matching('child.a2 == 11'))
    assert_equal(['id:test:child::3'],
                 enumerate_docs_matching('child.a2 == 13'))
    # No parent with matching field value.
    assert_equal([],
                 enumerate_docs_matching('child.a2 == 14'))
    # Match transitively through parent -> grandparent.
    assert_equal(['id:test:child::0', 'id:test:child::3', 'id:test:child::4'],
                 enumerate_docs_matching('child.a1 == 5'))
    assert_equal(['id:test:child::0', 'id:test:child::4'],
                 enumerate_docs_matching('child.a1 == 5 and child.a2 == 10'))
    # Match in both child, parent and grandparent.
    assert_equal(['id:test:child::5'],
                 enumerate_docs_matching('child.a3 == 105 and child.a2 == 11 and child.a1 == 6'))
    # Grandparent mismatch.
    assert_equal([],
                 enumerate_docs_matching('child.a2 == 11 and child.a1 == 7'))

    # Parent with a2 == 12 has grandparent ref of #2 which doesn't exist; should not be a match.
    assert_equal([],
                 enumerate_docs_matching('child.a2 == 12 and child.a1 > 0'))
    # Import via missing reference should be treated as if a field is missing from the
    # document itself (null-semantics).
    assert_equal(['id:test:child::2'],
                 enumerate_docs_matching('child.a2 == 12 and child.a1 == null'))
    assert_equal(['id:test:child::2'],
                 enumerate_docs_matching('child.a1 == null'))
    assert_equal(['id:test:child::0', 'id:test:child::1', 'id:test:child::3',
                  'id:test:child::4', 'id:test:child::5'],
                 enumerate_docs_matching('child.a1 != null'))
    # All imported refs to 'parent' doctype (not 'grandparent') should be valid.
    assert_equal([],
                 enumerate_docs_matching('child.a2 == null'))

    # Can select in non-default bucket space.
    assert_equal(['id:test:parent::0', 'id:test:parent::3'],
                 enumerate_docs_matching('parent.a1 == 5', 'global'))
    assert_equal(['id:test:parent::3'],
                 enumerate_docs_matching('parent.a1 == 5 and parent.a2 == 13', 'global'))
  end

  def wait_until_doc_set_is(expected, bucket_space = 'default')
    puts "Waiting for document set in bucket space '#{bucket_space}' to be: #{expected}"
    docs = []
    60.times do |n|
      sleep gc_interval_secs
      docs = enumerate_docs_matching('true', bucket_space)
      if docs == expected
        puts "Document set matches!"
        return
      end
    end
    flunk("Expected document set to be #{expected}, but was #{docs}")
  end

  def update_grandparent_a1_field(grandparent:, new_value:)
    update = DocumentUpdate.new('grandparent', "id:test:grandparent::#{grandparent}")
    update.addOperation('assign', 'a1', new_value)
    vespa.document_api_v1.update(update)
  end

  def update_parent_ref_field(parent:, new_grandparent:)
    update = DocumentUpdate.new('parent', "id:test:parent::#{parent}")
    update.addOperation('assign', 'ref', "id:test:grandparent::#{new_grandparent}")
    vespa.document_api_v1.update(update)
  end

  def put_grandparent_doc(grandparent:, a1_value:)
    doc = Document.new('grandparent', "id:test:grandparent::#{grandparent}").add_field('a1', a1_value)
    vespa.document_api_v1.put(doc)
  end

  def do_test_imported_fields_can_be_used_in_gc_document_selections(searchable_copies:)
    set_description('Test that imported fields can be used in GC document selections. ' +
                    'Also implicitly tests passing updates and removes through a ' +
                    'pipeline with imported fields as part of the selection criteria')

    deploy_app(make_app(with_gc: true, searchable_copies: searchable_copies))
    start

    feed_docs_with_references

    # After feed, all child docs should be present since none of them are hit by the GC
    # expression and they should be explicitly allowed through the feed pipeline.
    wait_until_doc_set_is(['id:test:child::0', 'id:test:child::1', 'id:test:child::2',
                           'id:test:child::3', 'id:test:child::4', 'id:test:child::5'])

    # Rewrite a1 field in grandparent 0 doc transitively referred to by child docs {0, 3, 4}.
    update_grandparent_a1_field(grandparent: 0, new_value: 7)
    # These documents should now be removed as soon as a new GC cycle completes.
    wait_until_doc_set_is(['id:test:child::1', 'id:test:child::2', 'id:test:child::5'])
    # Global document set should be unchanged.
    wait_until_doc_set_is(['id:test:grandparent::0', 'id:test:grandparent::1', 'id:test:parent::0',
                           'id:test:parent::1', 'id:test:parent::2', 'id:test:parent::3', ], 'global')

    # Reset a1 to ensure new documents pointing to grandparent 0 won't be GC'd.
    update_grandparent_a1_field(grandparent: 0, new_value: 6)

    # Point parent for children 1 and 5 to grandparent 0. Since its a1 field matches the GC
    # selection, the documents shall be preserved.
    update_parent_ref_field(parent: 1, new_grandparent: 0)

    sleep gc_interval_secs * 2
    wait_until_doc_set_is(['id:test:child::1', 'id:test:child::2', 'id:test:child::5'])

    # Remove grandparent 1. This should have no observable effect since no children reference it.
    vespa.document_api_v1.remove('id:test:grandparent::1')
    # (make sure the remove has been allowed through the feed pipeline, though)
    assert_equal(nil, vespa.document_api_v1.get('id:test:grandparent::1'))

    sleep gc_interval_secs * 2
    wait_until_doc_set_is(['id:test:child::1', 'id:test:child::2', 'id:test:child::5'])

    # Make docs pointing to grandparent 0 GC-able once more.
    update_grandparent_a1_field(grandparent: 0, new_value: 7)

    # The lone survivor is child #2 since it does not have a valid grandparent reference.
    wait_until_doc_set_is(['id:test:child::2'])

    # ... but not for long! Establish a reference connection by feeding the grandparent with
    # a value that triggers the child to be GC'd.
    put_grandparent_doc(grandparent: 2, a1_value: 4)
    wait_until_doc_set_is([])
  end

  def test_imported_fields_can_be_used_in_gc_document_selections_subset_ready
    do_test_imported_fields_can_be_used_in_gc_document_selections(searchable_copies: 1)
  end

  def test_imported_fields_can_be_used_in_gc_document_selections_all_ready
    do_test_imported_fields_can_be_used_in_gc_document_selections(searchable_copies: 3)
  end

end

