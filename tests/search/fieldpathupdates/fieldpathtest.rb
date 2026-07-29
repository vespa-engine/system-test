# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class FieldPath < IndexedStreamingSearchTest

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

  # Every element of a field assigned in the same update document.
  AFTER_ASSIGN_EVERY_ELEMENT = BEFORE.merge(
    "attr_int"     => [7, 8, 9],
    "doc_int"      => [7, 8, 9],
    "idx_attr_str" => ["x", "y", "z"]
  )

  # remove ["a"] applies before the element assign [1] = "x", so the assign
  # observes the shrunken array: ["a","b","c"] -> ["b","c"] -> ["b","x"].
  # Holds whether the two operations arrive in one update or in consecutive
  # updates within the same commit window.
  AFTER_REMOVE_THEN_ASSIGN = BEFORE.merge(
    "attr_str"     => ["b", "x"],
    "doc_str"      => ["b", "x"],
    "idx_attr_str" => ["b", "x"]
  )

  def setup
    set_owner("johsol")
    set_description("Test that element updates give the same end data in every field " +
                    "representation: index, attribute and document store (summary)")

    deploy_app(SearchApp.new.sd(selfdir + "test_field_path.sd"))
    start
    feedfile(selfdir + "feed.json")
  end

  def test_assign_element
    assert_document(BEFORE)
    assert_search(%w[attr_int:1 idx_str:a idx_attr_str:a], %w[attr_int:4 idx_str:d idx_attr_str:d])

    feedfile(selfdir + "update_assign_element.json")

    assert_document(AFTER_ASSIGN_ELEMENT)
    assert_search(%w[attr_int:4 idx_str:d idx_attr_str:d], %w[attr_int:1 idx_str:a idx_attr_str:a])
  end

  def test_assign_element_using_match
    assert_document(BEFORE)

    feedfile(selfdir + "update_assign_element_using_match.json")

    assert_document(AFTER_ASSIGN_ELEMENT)
    assert_search(%w[attr_int:4 idx_str:d idx_attr_str:d], %w[attr_int:1 idx_str:a idx_attr_str:a])
  end

  def test_assign_element_out_of_bounds
    assert_document(BEFORE)

    feedfile(selfdir + "update_out_of_bounds.json")

    # Out of bounds element updates are a no-op in every representation.
    assert_document(BEFORE)
    assert_search(%w[attr_int:1 idx_str:a idx_attr_str:a], %w[attr_int:9 idx_str:z idx_attr_str:z])
  end

  def test_assign_every_element_in_one_update
    assert_document(BEFORE)

    feedfile(selfdir + "update_assign_every_element.json")

    assert_document(AFTER_ASSIGN_EVERY_ELEMENT)
    assert_search(%w[attr_int:7 attr_int:8 attr_int:9 idx_attr_str:x idx_attr_str:y idx_attr_str:z],
                  %w[attr_int:1 idx_attr_str:a])
  end

  def test_remove_then_assign_element_in_one_update
    assert_document(BEFORE)

    feedfile(selfdir + "update_remove_then_assign.json")

    assert_document(AFTER_REMOVE_THEN_ASSIGN)
    assert_search(%w[idx_attr_str:x], %w[idx_attr_str:a idx_attr_str:c])
  end

  def test_remove_then_assign_element_in_consecutive_updates
    assert_document(BEFORE)

    feedfile(selfdir + "update_remove_then_assign_sequence.json")

    assert_document(AFTER_REMOVE_THEN_ASSIGN)
    assert_search(%w[idx_attr_str:x], %w[idx_attr_str:a idx_attr_str:c])
  end

  # Asserts the document content served by summary, field by field. Fields
  # backed by an attribute are served from the attribute, doc_* fields from
  # the document store.
  def assert_document(expected)
    result = search('yql=select * from sources * where true')
    assert_equal(1, result.hitcount)
    fields = result.hit[0].field
    expected.each do |name, value|
      assert_equal(value, fields[name], "Unexpected content of field '#{name}'")
    end
  end

  # Asserts through the search read path: matching terms must hit, removed
  # or overwritten terms must not.
  def assert_search(present, absent)
    present.each do |term|
      assert_hitcount("query=#{term}", 1)
    end
    absent.each do |term|
      assert_hitcount("query=#{term}", 0)
    end
  end

end
