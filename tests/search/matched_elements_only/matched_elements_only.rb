# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class MatchedElementsOnlyTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def create_app(test_case)
    SearchApp.new.sd(selfdir + "#{test_case}/test.sd")
  end

  def test_array_and_wset_fields
    # Note that the matched-elements-only tests for struct and map types are located in
    # tests/search/struct_and_map_types/struct_and_map_types.rb
    set_description("Test matched-elements-only for array and weighted set fields (both indexed and streaming search)")
    deploy_app(create_app(is_streaming ? "streaming" : "indexed"))
    start
    feed(:file => selfdir + "docs.json")

    # Test fields with explicit 'matched-elements-only'.
    assert_summary_field("str_array contains 'bar'", "str_array", ["bar"])
    assert_summary_field("int_array contains '20'", "int_array", [20])
    assert_summary_field("str_wset contains 'bar'", "str_wset", [elem("bar", 7)])
    assert_summary_field("int_wset contains '20'", "int_wset", [elem(20, 7)])
    assert_summary_field("str_array contains 'foo' or str_array contains 'bar'", "str_array", ["bar", "foo"])
    assert_summary_field("str_wset contains 'foo' or str_wset contains 'bar'", "str_wset", [elem("bar", 7), elem("foo", 5)])

    # Test summary fields with 'matched-elements-only' (in explicit summary class) that reference source fields.
    assert_summary_field("str_array_src contains 'bar'", "str_array_filtered", ["bar"], "filtered")
    assert_summary_field("int_array_src contains '20'", "int_array_filtered", [20], "filtered")
    assert_summary_field("str_wset_src contains 'bar'", "str_wset_filtered", [elem("bar", 7)], "filtered")
    assert_summary_field("int_wset_src contains '20'", "int_wset_filtered", [elem(20, 7)], "filtered")
    assert_summary_field("str_array_src contains 'foo' or str_array_src contains 'bar'", "str_array_filtered", ["bar", "foo"], "filtered")
    assert_summary_field("str_wset_src contains 'foo' or str_wset_src contains 'bar'", "str_wset_filtered", [elem("bar", 7), elem("foo", 5)], "filtered")

    # The source fields are not filtered
    assert_summary_field("str_array_src contains 'bar'", "str_array_src", ["bar", "foo"])
    assert_summary_field("str_wset_src contains 'bar'", "str_wset_src", [elem("bar", 7), elem("foo", 5)])
  end

  def elem(item, weight)
    {"item" => item, "weight" => weight}
  end

  def assert_summary_field(yql_filter, field_name, exp_field_value, summary = "default")
    query = "yql=select * from sources * where #{yql_filter};&format=json&streaming.selection=true&summary=#{summary}"
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
