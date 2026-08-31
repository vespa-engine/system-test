# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class MatchedElementsOnlyTest < IndexedStreamingSearchTest

  def setup
    set_owner("hmusum")
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

  def test_struct_field_select_and_matched_elements_only
    set_description("Test 'matched-elements-only' combined with a selection of a subset of the struct " +
                    "fields ('struct-field' in a document-summary)")
    deploy_app(create_app(is_streaming ? "structsel_streaming" : "structsel_indexed"))
    start
    feed(:file => selfdir + "structsel-docs.json")

    foo = { "name" => "foo", "weight" => 10 }
    bar = { "name" => "bar", "weight" => 20 }
    baz = { "name" => "baz", "weight" => 30 }
    smap_full = { "kone" => { "p2" => 11 }, "ktwo" => { "p2" => 22 } }
    imap_full = { "ione" => 1, "itwo" => 2 }
    # Note: Empty arrays and empty maps are not rendered in search results
    empty = nil

    # The selection alone: only the selected struct fields, but all the elements.
    assert_summary_field("arr.name contains 'bar'", "arr_sel", [foo, bar, baz], "sel")
    assert_summary_field("smap.value.p1 contains 'v2'", "smap_sel", smap_full, "sel")
    assert_summary_field("imap.key contains 'itwo'", "imap_sel", imap_full, "sel")

    # The selection combined with 'matched-elements-only': only the selected struct fields of the
    # matched elements.
    assert_summary_field("arr.name contains 'bar'", "arr_sel_meo", [bar], "sel_meo")
    assert_summary_field("arr.name contains 'bar' or arr.name contains 'baz'", "arr_sel_meo", [bar, baz], "sel_meo")
    assert_summary_field("arr.weight contains '20'", "arr_sel_meo", [bar], "sel_meo")
    assert_summary_field("arr contains sameElement(name contains 'bar', weight contains '20')", "arr_sel_meo", [bar], "sel_meo")
    assert_summary_field("smap.value.p1 contains 'v2'", "smap_sel_meo", { "ktwo" => { "p2" => 22 } }, "sel_meo")
    assert_summary_field("imap.key contains 'itwo'", "imap_sel_meo", { "itwo" => 2 }, "sel_meo")
    assert_summary_field("imap.value contains '2'", "imap_sel_meo", { "itwo" => 2 }, "sel_meo")

    # The struct field which the query matches need not be one of the selected ones.
    assert_summary_field("arr.name contains 'bar'", "arr_weight_meo", [{ "weight" => 20 }], "sel_meo")

    # A selection including a struct field which cannot be a struct field attribute ("aliases"),
    # which is filled from the document store also with indexed search.
    assert_summary_field("arr.name contains 'bar'", "arr_aliases_meo",
                         [{ "name" => "bar", "aliases" => ["b1"] }], "sel_meo")
    assert_summary_field("arr.weight contains '20'", "arr_aliases_meo",
                         [{ "name" => "bar", "aliases" => ["b1"] }], "sel_meo")

    # No elements matches in the other fields.
    assert_summary_field("imap.key contains 'itwo'", "arr_sel_meo", empty, "sel_meo")
    assert_summary_field("imap.key contains 'itwo'", "arr_aliases_meo", empty, "sel_meo")
    assert_summary_field("imap.key contains 'itwo'", "smap_sel_meo", empty, "sel_meo")
    assert_summary_field("arr.name contains 'bar'", "imap_sel_meo", empty, "sel_meo")
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
    assert_summary_field("str_array contains 'foo' or str_array contains 'bar'", "str_array", ["foo", "bar"])
    assert_summary_field("str_wset contains 'foo' or str_wset contains 'bar'", "str_wset", { "bar" => 7, "foo" => 5 })
    assert_summary_field("idx_array contains 'deux'", "idx_array", ["two 2 deux"])
    assert_summary_field("idx_array contains 'deux' or idx_array contains 'une'", "idx_array", ["one 1 une", "two 2 deux"])
    assert_summary_field("idx_wset contains 'deux'", "idx_wset", {"two 2 deux" => 7})
    assert_summary_field("idx_wset contains 'deux' or idx_wset contains 'une'", "idx_wset", {"one 1 une" => 5, "two 2 deux" => 7})
    assert_summary_field("weightedSet(str_array, {\"foo\":1, \"baz\":2})", "str_array", ["foo"])
    assert_summary_field("weightedSet(str_array, {\"baz\":1, \"bar\":2})", "str_array", ["bar"])
    assert_summary_field("weightedSet(str_array, {\"foo\":1, \"bar\":2})", "str_array", ["foo", "bar"])
    assert_summary_field("weightedSet(int_array, {\"10\":1, \"11\":2})", "int_array", [10])
    assert_summary_field("weightedSet(int_array, {\"11\":1, \"20\":2})", "int_array", [20])
    assert_summary_field("weightedSet(int_array, {\"10\":1, \"20\":2})", "int_array", [10, 20])
    assert_summary_field("weightedSet(str_wset, {\"foo\":1, \"baz\":2})", "str_wset", { "foo" => 5 })
    assert_summary_field("weightedSet(str_wset, {\"baz\":1, \"bar\":2})", "str_wset", { "bar" => 7 })
    assert_summary_field("weightedSet(str_wset, {\"foo\":1, \"bar\":2})", "str_wset", { "bar" => 7, "foo" => 5 })
    assert_summary_field("weightedSet(int_wset, {\"10\":1, \"11\":2})", "int_wset", { "10" => 5 })
    assert_summary_field("weightedSet(int_wset, {\"11\":1, \"20\":2})", "int_wset", { "20" => 7 })
    assert_summary_field("weightedSet(int_wset, {\"10\":1, \"20\":2})", "int_wset", { "10" => 5, "20" => 7 })
    assert_summary_field('weightedSet(idx_array, {"two":3, "deux": 5, "3":22})', "idx_array", ["two 2 deux", "three 3 trois"])
    assert_summary_field('weightedSet(idx_wset, {"two":3, "deux": 5, "3":22})', "idx_wset", {"three 3 trois" => 16, "two 2 deux" => 7})
    assert_summary_field('idx_array contains equiv("two", "deux", "3")', "idx_array", ["two 2 deux", "three 3 trois"])
    assert_summary_field('idx_wset contains equiv("two", "deux", "3")', "idx_wset", {"three 3 trois" => 16, "two 2 deux" => 7})

    # Test summary fields with 'matched-elements-only' (in explicit summary class) that reference source fields.
    assert_summary_field("str_array_src contains 'bar'", "str_array_filtered", ["bar"], "filtered")
    assert_summary_field("int_array_src contains '20'", "int_array_filtered", [20], "filtered")
    assert_summary_field("str_wset_src contains 'bar'", "str_wset_filtered", { "bar" => 7 }, "filtered")
    assert_summary_field("int_wset_src contains '20'", "int_wset_filtered", { "20" => 7 }, "filtered")
    assert_summary_field("str_array_src contains 'foo' or str_array_src contains 'bar'", "str_array_filtered", ["foo", "bar"], "filtered")
    assert_summary_field("str_wset_src contains 'foo' or str_wset_src contains 'bar'", "str_wset_filtered", { "bar" => 7, "foo" => 5 }, "filtered")
    assert_summary_field("idx_array_src contains 'deux'", "idx_array_filtered", ["two 2 deux"])
    assert_summary_field("idx_array_src contains 'deux' or idx_array_src contains '1'", "idx_array_filtered", ["one 1 une", "two 2 deux"])
    assert_summary_field("idx_wset_src contains 'deux' or idx_wset_src contains '1'", "idx_wset_filtered", {"one 1 une" => 5, "two 2 deux" => 7})

    # The source fields are not filtered
    assert_summary_field("str_array_src contains 'bar'", "str_array_src", ["foo", "bar"])
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

    # Search for i_arrays goes to two indexed array fields
    assert_summary_field("i_arrays contains 'one'", 'idx_array', ['one 1 une'])
    assert_summary_field("i_arrays contains 'one'", 'idx_array2', ['one 1 une'])
    unless is_streaming
      assert_summary_field("i_arrays contains equiv('one', 'two', '2')", 'idx_array', ['one 1 une', 'two 2 deux'])
      assert_summary_field("i_arrays contains equiv('one', 'two', '2')", 'idx_array2', ['two 2 deux', 'one 1 une'])
      assert_summary_field("i_arrays contains alternatives({'one':1.0, 'two':1.0, '2':1.0})", 'idx_array', ['one 1 une', 'two 2 deux'])
      assert_summary_field("i_arrays contains alternatives({'one':1.0, 'two':1.0, '2':1.0})", 'idx_array2', ['two 2 deux', 'one 1 une'])

      assert_summary_field("idx_array  contains phrase('one', '1', 'une')", 'idx_array',  ['one 1 une'])
      assert_summary_field("idx_array2 contains phrase('one', '1', 'une')", 'idx_array2', ['one 1 une'])
      assert_summary_field("i_arrays   contains phrase('one', '1', 'une')", 'idx_array',  ['one 1 une'])
      assert_summary_field("i_arrays   contains phrase('one', '1', 'une')", 'idx_array2', ['one 1 une'])
      assert_summary_field("idx_array  contains phrase('one', alternatives({'bad':1.0, '1':1.0, 'two':1.0}), 'une')", 'idx_array',  ['one 1 une'])
      assert_summary_field("idx_array2 contains phrase('one', alternatives({'bad':1.0, '1':1.0, 'two':1.0}), 'une')", 'idx_array2', ['one 1 une'])
      assert_summary_field("i_arrays   contains phrase('one', alternatives({'bad':1.0, '1':1.0, 'two':1.0}), 'une')", 'idx_array',  ['one 1 une'])
      assert_summary_field("i_arrays   contains phrase('one', alternatives({'bad':1.0, '1':1.0, 'two':1.0}), 'une')", 'idx_array2', ['one 1 une'])
    end

    # Search for fruit goes to both apples and oranges fields.
    assert_summary_field("fruit contains 'one'", 'apples', ['one'])
    # Search for fruit goes to both apples and oranges fields.
    assert_summary_field("fruit contains 'one'", 'apples', ['one'])
    assert_summary_field("fruit contains 'one'", 'oranges', ['one'])
    unless is_streaming
      assert_summary_field("fruit contains equiv('one', 'two')", 'apples', ['one', 'two'])
      assert_summary_field("fruit contains equiv('one', 'two')", 'oranges', ['two', 'one'])
      assert_summary_field("fruit contains alternatives({'one':1.0, 'two':1.0})", 'apples', ['one', 'two'])
      assert_summary_field("fruit contains alternatives({'one':1.0, 'two':1.0})", 'oranges', ['two', 'one'])
    end
  end

  def assert_summary_field(yql_filter, field_name, exp_field_value, summary = "default")
    query = "yql=select * from sources * where #{yql_filter}&format=json&summary=#{summary}"
    result = search(query)
    assert_hitcount(result, 1)
    hit = result.hit[0]
    act_field_value = hit.field[field_name]
    puts "Q: #{yql_filter} --> #{field_name} = #{act_field_value}"
    assert_equal(exp_field_value, act_field_value)
  end

end
