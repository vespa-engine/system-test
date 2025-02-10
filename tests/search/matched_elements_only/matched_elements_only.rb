# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class MatchedElementsOnlyTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def self.final_test_methods
    ["test_array_and_wset_fields_indexed_fs"]
  end

  def create_app(test_case)
    SearchApp.new.sd(selfdir + "#{test_case}/test.sd")
  end

  def test_array_and_wset_fields
    # Note that the matched-elements-only tests for struct and map types are located in
    # tests/search/struct_and_map_types/struct_and_map_types.rb
    set_description("Test matched-elements-only for array and weighted set fields (both indexed and streaming search)")
    run_test(is_streaming ? "streaming" : "indexed")
  end

  def test_array_and_wset_fields_indexed_fs
    @params = { :search_type => "INDEXED" }
    run_test("indexed_fs")
  end

  def run_test(test_dir)
    deploy_app(create_app(test_dir))
    start
    feed(:file => selfdir + "docs.json")

    # Test fields with explicit 'matched-elements-only'.
    assert_summary_field("str_array contains 'bar'", "str_array", ["bar"])
    assert_summary_field("int_array contains '20'", "int_array", [20])
    assert_summary_field("str_wset contains 'bar'", "str_wset", { "bar" => 7 })
    assert_summary_field("int_wset contains '20'", "int_wset", { "20" => 7 })
    assert_summary_field("str_array contains 'foo' or str_array contains 'bar'", "str_array", ["bar", "foo"])
    assert_summary_field("str_wset contains 'foo' or str_wset contains 'bar'", "str_wset", { "bar" => 7, "foo" => 5 })
    assert_summary_field("idx_array contains 'deux'", "idx_array", ["two 2 deux"])
    assert_summary_field("idx_array contains 'deux' or idx_array contains 'une'", "idx_array", ["one 1 une", "two 2 deux"])
    assert_summary_field("idx_wset contains 'deux'", "idx_wset", {"two 2 deux" => 7})
    assert_summary_field("idx_wset contains 'deux' or idx_wset contains 'une'", "idx_wset", {"one 1 une" => 5, "two 2 deux" => 7})
    assert_summary_field("weightedSet(str_array, {\"foo\":1, \"baz\":2})", "str_array", ["foo"])
    assert_summary_field("weightedSet(str_array, {\"baz\":1, \"bar\":2})", "str_array", ["bar"])
    assert_summary_field("weightedSet(str_array, {\"foo\":1, \"bar\":2})", "str_array", ["bar", "foo"])
    assert_summary_field("weightedSet(int_array, {\"10\":1, \"11\":2})", "int_array", [10])
    assert_summary_field("weightedSet(int_array, {\"11\":1, \"20\":2})", "int_array", [20])
    assert_summary_field("weightedSet(int_array, {\"10\":1, \"20\":2})", "int_array", [10, 20])
    assert_summary_field("weightedSet(str_wset, {\"foo\":1, \"baz\":2})", "str_wset", { "foo" => 5 })
    assert_summary_field("weightedSet(str_wset, {\"baz\":1, \"bar\":2})", "str_wset", { "bar" => 7 })
    assert_summary_field("weightedSet(str_wset, {\"foo\":1, \"bar\":2})", "str_wset", { "bar" => 7, "foo" => 5 })
    assert_summary_field("weightedSet(int_wset, {\"10\":1, \"11\":2})", "int_wset", { "10" => 5 })
    assert_summary_field("weightedSet(int_wset, {\"11\":1, \"20\":2})", "int_wset", { "20" => 7 })
    assert_summary_field("weightedSet(int_wset, {\"10\":1, \"20\":2})", "int_wset", { "10" => 5, "20" => 7 })
    assert_summary_field('weightedSet(idx_array, {"two":3, "deux": 5, "3":22})', "idx_array", ["three 3 trois", "two 2 deux"])
    assert_summary_field('weightedSet(idx_wset, {"two":3, "deux": 5, "3":22})', "idx_wset", {"three 3 trois" => 16, "two 2 deux" => 7})
    assert_summary_field('idx_array contains equiv("two", "deux", "3")', "idx_array", ["three 3 trois", "two 2 deux"])
    assert_summary_field('idx_wset contains equiv("two", "deux", "3")', "idx_wset", {"three 3 trois" => 16, "two 2 deux" => 7})

    # Test summary fields with 'matched-elements-only' (in explicit summary class) that reference source fields.
    assert_summary_field("str_array_src contains 'bar'", "str_array_filtered", ["bar"], "filtered")
    assert_summary_field("int_array_src contains '20'", "int_array_filtered", [20], "filtered")
    assert_summary_field("str_wset_src contains 'bar'", "str_wset_filtered", { "bar" => 7 }, "filtered")
    assert_summary_field("int_wset_src contains '20'", "int_wset_filtered", { "20" => 7 }, "filtered")
    assert_summary_field("str_array_src contains 'foo' or str_array_src contains 'bar'", "str_array_filtered", ["bar", "foo"], "filtered")
    assert_summary_field("str_wset_src contains 'foo' or str_wset_src contains 'bar'", "str_wset_filtered", { "bar" => 7, "foo" => 5 }, "filtered")
    assert_summary_field("idx_array_src contains 'deux'", "idx_array_filtered", ["two 2 deux"])
    assert_summary_field("idx_array_src contains 'deux' or idx_array_src contains '1'", "idx_array_filtered", ["one 1 une", "two 2 deux"])
    assert_summary_field("idx_wset_src contains 'deux' or idx_wset_src contains '1'", "idx_wset_filtered", {"one 1 une" => 5, "two 2 deux" => 7})

    # The source fields are not filtered
    assert_summary_field("str_array_src contains 'bar'", "str_array_src", ["bar", "foo"])
    assert_summary_field("str_wset_src contains 'bar'", "str_wset_src", { "bar" => 7, "foo" => 5 })

    # No elements matches in other fields
    query = "int_array contains '20'"
    # Note: Empty arrays and empty weighted sets are not rendered in search results
    empty_array = nil
    empty_wset = nil
    assert_summary_field(query, "str_array", empty_array)
    assert_summary_field("str_array contains 'bar'", "int_array", empty_array)
    assert_summary_field(query, "str_wset", empty_wset)
    assert_summary_field(query, "int_wset", empty_wset)

    # Search for fruit goes to both apples and oranges fields.
    assert_summary_field("fruit contains 'one'", 'apples', ['one'])
    assert_summary_field("fruit contains 'one'", 'oranges', ['one'])
  end

  def assert_summary_field(yql_filter, field_name, exp_field_value, summary = "default")
    query = "yql=select * from sources * where #{yql_filter}&format=json&summary=#{summary}"
    result = search(query)
    assert_hitcount(result, 1)
    hit = result.hit[0]
    act_field_value = hit.field[field_name]
    assert_equal(exp_field_value, act_field_value)
  end

  def teardown
    stop
  end
end
