# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class MatchedElementsOnlyTest < SearchTest

  def setup
    set_owner("geirst")
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd")
  end

  def test_array_and_wset_attributes
    # Note that the matched-elements-only tests for struct and map types are located in
    # tests/search/struct_and_map_types/struct_and_map_types.rb
    set_description("Test matched-elements-only for array and weighted set attributes")
    deploy_app(create_app)
    start
    feed(:file => selfdir + "docs.json")

    assert_summary_field("str_array contains 'bar'", "str_array", ["bar"])
    assert_summary_field("int_array contains '20'", "int_array", [20])
    assert_summary_field("str_wset contains 'bar'", "str_wset", [elem("bar", 7)])
    assert_summary_field("int_wset contains '20'", "int_wset", [elem(20, 7)])

    assert_summary_field("str_array contains 'foo' or str_array contains 'bar'", "str_array", ["bar", "foo"])
    assert_summary_field("str_wset contains 'foo' or str_wset contains 'bar'", "str_wset", [elem("bar", 7), elem("foo", 5)])
  end

  def elem(item, weight)
    {"item" => item, "weight" => weight}
  end

  def assert_summary_field(yql_filter, field_name, exp_field_value)
    query = "yql=select * from sources * where #{yql_filter};&format=json"
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
