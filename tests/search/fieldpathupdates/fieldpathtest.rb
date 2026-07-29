# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class FieldPath < IndexedStreamingSearchTest

  def setup
    set_owner("johsol")
    set_description("Test that element updates give the same end data in every field " +
                    "representation: index, attribute and summary.")

    deploy_app(SearchApp.new.sd(selfdir + "test_field_path.sd"))
    start
    feedfile(selfdir + "feed.json")
  end

  # Document 1 as fed.
  BEFORE = {
    "attr_int"     => [1, 2, 3],
    "doc_int"      => [1, 2, 3],
    "attr_str"     => ["a", "b", "c"],
    "doc_str"      => ["a", "b", "c"],
    "attr_map"     => {"a" => 1, "b" => 2, "c" => 3},
    "doc_map"      => {"a" => 1, "b" => 2, "c" => 3},
    "idx_str"      => ["a", "b", "c"],
    "idx_attr_str" => ["a", "b", "c"]
  }

  # Element assign to index 0 / map key "a".
  AFTER_ASSIGN_ELEMENT = BEFORE.merge(
    "attr_int"     => [4, 2, 3],
    "doc_int"      => [4, 2, 3],
    "attr_str"     => ["d", "b", "c"],
    "doc_str"      => ["d", "b", "c"],
    "attr_map"     => {"a" => 5, "b" => 2, "c" => 3},
    "doc_map"      => {"a" => 5, "b" => 2, "c" => 3},
    "idx_str"      => ["d", "b", "c"],
    "idx_attr_str" => ["d", "b", "c"]
  )

  # The match encoding cannot address map fields. Map fields are only updatable
  # with the field path encoding, so the match update omits them.
  AFTER_ASSIGN_ELEMENT_USING_MATCH = AFTER_ASSIGN_ELEMENT.merge(
    "attr_map" => BEFORE["attr_map"],
    "doc_map"  => BEFORE["doc_map"]
  )

  # Every element of a field assigned in the same update document.
  AFTER_ASSIGN_EVERY_ELEMENT = BEFORE.merge(
    "attr_int"     => [7, 8, 9],
    "doc_int"      => [7, 8, 9],
    "idx_attr_str" => ["x", "y", "z"]
  )

  # remove ["a"] applies before the element assign at index 1 = "x", so the assign
  # observes the shrunken array: ["a","b","c"] -> ["b","c"] -> ["b","x"].
  # Holds whether the two operations arrive in one update or in consecutive
  # updates within the same commit window.
  AFTER_REMOVE_THEN_ASSIGN = BEFORE.merge(
    "attr_str"     => ["b", "x"],
    "doc_str"      => ["b", "x"],
    "idx_attr_str" => ["b", "x"]
  )

  # Document ids, one per scenario.
  ASSIGN_ELEMENT                     = 1
  OUT_OF_BOUNDS                      = 2
  ASSIGN_EVERY_ELEMENT               = 3
  REMOVE_THEN_ASSIGN                 = 4
  REMOVE_THEN_ASSIGN_CONSECUTIVE     = 5
  ASSIGN_ELEMENT_USING_MATCH         = 6

  ALL_DOCS = [ASSIGN_ELEMENT, OUT_OF_BOUNDS, ASSIGN_EVERY_ELEMENT, REMOVE_THEN_ASSIGN,
              REMOVE_THEN_ASSIGN_CONSECUTIVE, ASSIGN_ELEMENT_USING_MATCH]

  def test_field_path_updates
    ALL_DOCS.each do |docid|
      assert_document(docid, BEFORE)
    end

    assert_search(ASSIGN_ELEMENT, %w[attr_int:1 idx_str:a idx_attr_str:a], %w[attr_int:4 idx_str:d idx_attr_str:d])

    # Each update file is fed separately. In particular the consecutive updates must
    # stay adjacent in their own feed so they land in the same commit window.
    feedfile(selfdir + "update_assign_element.json")
    feedfile(selfdir + "update_out_of_bounds.json")
    feedfile(selfdir + "update_assign_every_element.json")
    feedfile(selfdir + "update_remove_then_assign.json")
    feedfile(selfdir + "update_remove_then_assign_sequence.json")

    # Element assign to index 0 / map key "a".
    assert_document(ASSIGN_ELEMENT, AFTER_ASSIGN_ELEMENT)
    assert_search(ASSIGN_ELEMENT, %w[attr_int:4 idx_str:d idx_attr_str:d], %w[attr_int:1 idx_str:a idx_attr_str:a])

    # Out of bounds element updates are a no-op in every representation.
    assert_document(OUT_OF_BOUNDS, BEFORE)
    assert_search(OUT_OF_BOUNDS, %w[attr_int:1 idx_str:a idx_attr_str:a], %w[attr_int:9 idx_str:z idx_attr_str:z])

    # Every element of a field assigned in the same update document.
    assert_document(ASSIGN_EVERY_ELEMENT, AFTER_ASSIGN_EVERY_ELEMENT)
    assert_search(ASSIGN_EVERY_ELEMENT,
                  %w[attr_int:7 attr_int:8 attr_int:9 idx_attr_str:x idx_attr_str:y idx_attr_str:z],
                  %w[attr_int:1 idx_attr_str:a])

    # Remove followed by element assign, in one update and in consecutive updates.
    [REMOVE_THEN_ASSIGN, REMOVE_THEN_ASSIGN_CONSECUTIVE].each do |docid|
      assert_document(docid, AFTER_REMOVE_THEN_ASSIGN)
      assert_search(docid, %w[idx_attr_str:x], %w[idx_attr_str:a idx_attr_str:c])
    end

    # Documents not targeted by any update above are untouched.
    assert_document(ASSIGN_ELEMENT_USING_MATCH, BEFORE)
  end

  # Kept as a separate test since match updates of array attributes depend on
  # attribute support that is not in every Vespa version yet.
  def test_assign_element_using_match
    assert_document(ASSIGN_ELEMENT_USING_MATCH, BEFORE)

    feedfile(selfdir + "update_assign_element_using_match.json")

    assert_document(ASSIGN_ELEMENT_USING_MATCH, AFTER_ASSIGN_ELEMENT_USING_MATCH)
    assert_search(ASSIGN_ELEMENT_USING_MATCH, %w[attr_int:4 idx_str:d idx_attr_str:d], %w[attr_int:1 idx_str:a idx_attr_str:a])
  end

  # Asserts the document content served by summary, field by field. Fields
  # backed by an attribute are served from the attribute, doc_* fields from
  # the document store.
  def assert_document(docid, expected)
    result = search("yql=select * from sources * where docid = #{docid}")
    assert_equal(1, result.hitcount, "Expected exactly one hit for docid #{docid}")
    fields = result.hit[0].field
    expected.each do |name, value|
      assert_equal(value, fields[name], "Unexpected content of field '#{name}' in docid #{docid}")
    end
  end

  # Asserts through the search read path: matching terms must hit, removed
  # or overwritten terms must not. Restricted to the given document, since
  # other scenarios' documents may legitimately contain the same terms.
  def assert_search(docid, present, absent)
    present.each do |term|
      assert_hitcount(scoped_query(docid, term), 1)
    end
    absent.each do |term|
      assert_hitcount(scoped_query(docid, term), 0)
    end
  end

  # Turns 'field:value' into a YQL query for that term within the given document.
  def scoped_query(docid, term)
    field, value = term.split(":", 2)
    "yql=select * from sources * where docid = #{docid} and #{field} contains \"#{value}\""
  end

end
