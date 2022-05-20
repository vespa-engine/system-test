# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'search/struct_and_map_types/struct_and_map_base'

class StructAndMapTypesTest < IndexedStreamingSearchTest

  include StructAndMapBase

  def setup
    set_owner("geirst")
    @has_summary_features = false
  end

  def self.final_test_methods
    ["test_feed_and_retrieval_on_attribute_fields",
     "test_search_in_map_and_array_of_struct_paged_attribute",
     "test_numeric_range_search_when_using_fast_search"]
  end

  def create_app(test_case)
    SearchApp.new.sd(selfdir + "#{test_case}/test.sd").
      container(Container.new.documentapi(ContainerDocumentApi.new).search(Searching.new))
  end

  def setup_http
    container = vespa.container.values.first
    @http = https_client.create_client(container.name, container.http_port)
  end

  def deploy_and_start(test_case)
    deploy_app(create_app(test_case))
    start
    setup_http
  end

  def test_feed_and_retrieval_on_regular_fields
    set_description("Test feed operations and retrieval on regular array of struct and map of struct fields")
    deploy_and_start(is_streaming ? "streaming_fields" : "regular_fields")
    run_test
  end

  def test_feed_and_retrieval_on_attribute_fields
    @params = { :search_type => "ELASTIC" }
    set_description("Test feed operations and retrieval on attribute array of struct and map of struct fields")
    deploy_and_start("attribute_fields")
    @has_summary_features = true
    run_test
  end

  def run_test_search_in_map_and_array_of_struct_attribute
    feed(:file => selfdir + "docs_search.json")
    vespa.adminserver.logctl("searchnode:proton.matching.query", "debug=on")

    #Tests for array<struct>
    assert_same_element_single("elem_array", "name contains 'not'", 0)
    assert_same_element_single("elem_array", "name contains 'foo'", 1)
    assert_same_element_single("elem_array", "name contains 'bar'", 1)
    assert_same_element_single("elem_array", "name contains 'baz'", 2)
    assert_same_element_single("elem_array", "weight contains '5'", 0)
    assert_same_element_single("elem_array", "weight contains '10'", 1)
    assert_same_element_single("elem_array", "weight contains '20'", 1)
    assert_same_element_single("elem_array", "weight contains '30'", 2)
    assert_same_element("elem_array", "name contains 'bar', weight contains '10'", 0)
    assert_same_element("elem_array", "name contains 'bar', weight contains '20'", 1, "&ranking=unranked")
    assert_same_element("elem_array", "name contains 'bar', weight contains '20'", 1)
    assert_same_element("elem_array", "name contains 'baz', weight contains '30'", 2)

    #Tests for map<string, struct>
    assert_same_element_single("elem_map", "key contains 'not'", 0)
    assert_same_element_single("elem_map", "key contains '@foo'", 1)
    assert_same_element_single("elem_map", "key contains '@bar'", 1)
    assert_same_element_single("elem_map", "key contains '@baz'", 2)
    assert_same_element_single("elem_map", "value.name contains 'not'", 0)
    assert_same_element_single("elem_map", "value.name contains 'foo'", 1)
    assert_same_element_single("elem_map", "value.name contains 'bar'", 1)
    assert_same_element_single("elem_map", "value.name contains 'baz'", 2)
    assert_same_element_single("elem_map", "value.weight contains '5'", 0)
    assert_same_element_single("elem_map", "value.weight contains '10'", 1)
    assert_same_element_single("elem_map", "value.weight contains '20'", 1)
    assert_same_element_single("elem_map", "value.weight contains '30'", 2)
    assert_same_element("elem_map", "value.name contains 'bar', value.weight contains '10'", 0)
    assert_same_element("elem_map", "value.name contains 'bar', value.weight contains '20'", 1, "&ranking=unranked")
    assert_same_element("elem_map", "value.name contains 'bar', value.weight contains '20'", 1)
    assert_same_element("elem_map", "value.name contains 'baz', value.weight contains '30'", 2)
    assert_same_element("elem_map", "key contains '@foo', value.name contains 'bar', value.weight contains '20'", 0)
    assert_same_element("elem_map", "key contains '@bar', value.name contains 'bar', value.weight contains '20'", 1)
    assert_same_element("elem_map", "key contains '@baz', value.name contains 'baz', value.weight contains '30'", 2)

    #Tests for map<string, int>
    assert_same_element_single("str_int_map", "key contains 'not'", 0)
    assert_same_element_single("str_int_map", "key contains '@foo'", 1)
    assert_same_element_single("str_int_map", "key contains '@bar'", 1)
    assert_same_element_single("str_int_map", "key contains '@baz'", 2)
    assert_same_element_single("str_int_map", "value contains '5'", 0)
    assert_same_element_single("str_int_map", "value contains '10'", 1)
    assert_same_element_single("str_int_map", "value contains '20'", 1)
    assert_same_element_single("str_int_map", "value contains '30'", 2)
    assert_same_element("str_int_map", "key contains '@bar', value contains '10'", 0)
    assert_same_element("str_int_map", "key contains '@bar', value contains '20'", 1, "&ranking=unranked")
    assert_same_element("str_int_map", "key contains '@bar', value contains '20'", 1)
    assert_same_element("str_int_map", "key contains '@baz', value contains '30'", 2)

    #Tests for lowercasing
    assert_same_element_single("elem_array", "name contains 'BAZ'", 2)
    assert_same_element_single("str_int_map", "key contains 'NOT'", 0)
    assert_same_element_single("str_int_map", "key contains '@FOO'", 1)
    assert_same_element("str_int_map", "key contains '@BAR', value contains '20'", 1)
    assert_same_element("str_int_map", "key contains '@BAZ', value contains '30'", 2)
  end

  def test_search_in_map_and_array_of_struct_attribute
    set_description("Test search in map and array of struct attributes")
    deploy_and_start(is_streaming ? "streaming_fields" : "attribute_fields")
    run_test_search_in_map_and_array_of_struct_attribute
  end

  def test_search_in_map_and_array_of_struct_paged_attribute
    set_description("Test search in map and array of struct paged attributes")
    deploy_and_start("paged_attribute_fields")
    run_test_search_in_map_and_array_of_struct_attribute
  end

  def test_exact_match_search
    set_description("Test exact match and regular word match in the struct field attributes of a map field")
    deploy_and_start(is_streaming ? "streaming_exact_match" : "exact_match")
    feed(:file => selfdir + "exact_match/docs.json")

    assert_exact_match_queries("props_exact")
    assert_exact_match_queries("props_word")
  end

  def assert_exact_match_queries(field_name)
    assert_same_element_single(field_name, "key contains 'tag_one'", 1)
    assert_same_element_single(field_name, "key contains 'tag one'", 0)
    assert_same_element_single(field_name, "value contains 'android_one'", 1)
    assert_same_element_single(field_name, "value contains 'android one'", 0)
    assert_same_element(field_name, "key contains 'tag_one', value contains 'android_one'", 1)
  end

  def test_numeric_range_search_when_using_fast_search
    set_description("Test that numeric range search with 'fast-search' (that triggers use of bit vectors) works with sameElement operator")
    deploy_and_start("range_fast_search")
    feed(:file => selfdir + "range_fast_search/docs.json")

    assert_same_element("assets", "type contains 'mp4', pixels >786431", 5)
    assert_same_element("assets", "type contains 'mp4', pixels >786432", 3)
    assert_same_element("assets", "type contains 'mp4', pixels >921599", 3)
    assert_same_element("assets", "type contains 'mp4', pixels >921600", 1)
    assert_same_element("assets", "type contains 'mp4', pixels >1799999", 1)
    assert_same_element("assets", "type contains 'mp4', pixels >1800000", 0)

    assert_same_element("assets", "type contains 'mp4', pixels <1800001", 5)
    assert_same_element("assets", "type contains 'mp4', pixels <1800000", 4)
    assert_same_element("assets", "type contains 'mp4', pixels <921601", 4)
    assert_same_element("assets", "type contains 'mp4', pixels <921600", 2)
    assert_same_element("assets", "type contains 'mp4', pixels <786433", 2)
    assert_same_element("assets", "type contains 'mp4', pixels <786432", 0)
  end

  def test_filtered_elements_in_document_summary
    set_description("Test that we can filter elements in document summary")
    deploy_and_start(is_streaming ? "streaming_fields" : "attribute_fields")
    feed(:file => selfdir + "docs_search.json")

    array_full = [elem("foo", 10), elem("bar", 20), elem("baz", 30)]
    array_filtered = [elem("bar", 20)]
    map_full = {"@foo" => elem("foo", 10), "@bar" => elem("bar", 20), "@baz" => elem("baz", 30)}
    map_filtered = {"@bar" => elem("bar", 20)}
    prim_map_full = {"@foo" => 10, "@bar" => 20, "@baz" => 30}
    prim_map_filtered = {"@bar" => 20}
    complex_map_full = {"@foo" => complex_elem("foo", 10, "aa", 11), "@bar" => complex_elem("bar", 20, "bb", 21)}
    complex_map_filtered = {"@bar" => complex_elem("bar", 20, "bb", 21)}

    map_same_elem_query = "key contains '@bar', value.weight contains '20'"

    assert_same_element_summary("elem_array",     "name contains 'bar', weight contains '20'", "default",  "elem_array",          array_full)
    assert_same_element_summary("elem_array",     "name contains 'bar', weight contains '20'", "filtered", "elem_array_filtered", array_filtered)
    assert_same_element_summary("elem_array_meo", "name contains 'bar', weight contains '20'", "default",  "elem_array_meo",      array_filtered)

    assert_same_element_summary("elem_map",       map_same_elem_query, "default",  "elem_map",            map_full)
    assert_same_element_summary("elem_map",       map_same_elem_query, "filtered", "elem_map_filtered",   map_filtered)
    assert_same_element_summary("elem_map_meo",   map_same_elem_query, "default",  "elem_map_meo",        map_filtered)
    assert_same_element_summary("elem_map_2",     map_same_elem_query, "filtered", "elem_map_2_filtered", map_filtered)
    assert_same_element_summary("elem_map_2_meo", map_same_elem_query, "default",  "elem_map_2_meo",      map_filtered)

    assert_same_element_summary("str_int_map",     "key contains '@bar', value contains '20'", "default",  "str_int_map",          prim_map_full)
    assert_same_element_summary("str_int_map",     "key contains '@bar', value contains '20'", "filtered", "str_int_map_filtered", prim_map_filtered)
    assert_same_element_summary("str_int_map_meo", "key contains '@bar', value contains '20'", "default",  "str_int_map_meo",      prim_map_filtered)

    assert_same_element_summary("complex_elem_map",     map_same_elem_query, "default",  "complex_elem_map",          complex_map_full)
    assert_same_element_summary("complex_elem_map",     map_same_elem_query, "filtered", "complex_elem_map_filtered", complex_map_filtered)
    assert_same_element_summary("complex_elem_map_meo", map_same_elem_query, "default",  "complex_elem_map_meo",      complex_map_filtered)


    map_key_query = "key contains '@bar'"

    assert_same_element_single_summary("elem_array",     "name contains 'bar'", "default",  "elem_array",          array_full)
    assert_same_element_single_summary("elem_array",     "name contains 'bar'", "filtered", "elem_array_filtered", array_filtered)
    assert_same_element_single_summary("elem_array_meo", "name contains 'bar'", "default",  "elem_array_meo",      array_filtered)

    assert_same_element_single_summary("elem_map",       map_key_query, "default",  "elem_map",            map_full)
    assert_same_element_single_summary("elem_map",       map_key_query, "filtered", "elem_map_filtered",   map_filtered)
    assert_same_element_single_summary("elem_map_meo",   map_key_query, "default",  "elem_map_meo",        map_filtered)
    assert_same_element_single_summary("elem_map_2",     map_key_query, "filtered", "elem_map_2_filtered", map_filtered)
    assert_same_element_single_summary("elem_map_2_meo", map_key_query, "default",  "elem_map_2_meo",      map_filtered)

    assert_same_element_single_summary("str_int_map",     map_key_query, "default",  "str_int_map",          prim_map_full)
    assert_same_element_single_summary("str_int_map",     map_key_query, "filtered", "str_int_map_filtered", prim_map_filtered)
    assert_same_element_single_summary("str_int_map_meo", map_key_query, "default",  "str_int_map_meo",      prim_map_filtered)

    assert_same_element_single_summary("complex_elem_map",     map_key_query, "default",  "complex_elem_map",          complex_map_full)
    assert_same_element_single_summary("complex_elem_map",     map_key_query, "filtered", "complex_elem_map_filtered", complex_map_filtered)
    assert_same_element_single_summary("complex_elem_map_meo", map_key_query, "default",  "complex_elem_map_meo",      complex_map_filtered)
  end

  def assert_same_element(field, same_element, exp_hitcount, extra_params = "")
    query = "yql=select %2a from sources %2a where #{field} contains sameElement(#{same_element})&streaming.selection=true#{extra_params}"
    puts "assert_same_element(#{query}, #{exp_hitcount})"
    assert_hitcount(query, exp_hitcount)
  end

  def assert_same_element_single(field, same_element, exp_hitcount, extra_params = "")
    query = "yql=select %2a from sources %2a where #{field}.#{same_element}&streaming.selection=true#{extra_params}"
    query_same = "yql=select %2a from sources %2a where #{field} contains sameElement(#{same_element})&streaming.selection=true#{extra_params}"
    assert_hitcount(query, exp_hitcount)
    assert_hitcount(query_same, exp_hitcount)
  end

  def run_test
    @default_array = [elem("foo", 10), elem("bar", 20)]
    @default_map = {"@foo" => elem("foo", 10), "@bar" => elem("bar", 20)}
    @default_str_int_map = {"@foo" => 10, "@bar" => 20}

    run_test_case("assign_complete.json",
                  [elem("bar", 200), elem("baz", 300)],
                  {"@baz" => elem("baz", 300), "@bar" => elem("bar", 200)},
                  {"@baz" => 300, "@bar" => 200})

    run_test_case("assign_null.json", nil, nil, nil)

    run_test_cases("assign_elem.json",
                   [elem("foo", 10), elem("baz", 300)],
                   {"@foo" => elem("foo", 10), "@bar" => elem("baz", 300)},
                   {"@foo" => 10, "@bar" => 300})

    run_test_case("assign_elem_new.json",
                  @default_array,
                  {"@foo" => elem("foo", 10), "@bar" => elem("bar", 20), "@baz" => elem("baz", 300)},
                  {"@foo" => 10, "@bar" => 20, "@baz" => 300})

    run_test_cases("assign_elem_partial.json",
                   [elem("foo", 10), elem_weight(300)],
                   {"@foo" => elem("foo", 10), "@bar" => elem_weight(300)},
                   @default_str_int_map)

    run_test_case("add_elem.json",
                  [elem("foo", 10), elem("bar", 20), elem("baz", 300)],
                  @default_map,
                  @default_str_int_map)
   
    run_test_cases("increment_elem.json",
                   [elem("foo", 10), elem("bar", 40)],
                   {"@foo" => elem("foo", 10), "@bar" => elem("bar", 30)},
                   {"@foo" => 50, "@bar" => 20})

    run_test_cases("remove_elem.json",
                   [elem("bar", 20)],
                   {"@bar" => elem("bar", 20)},
                   {"@bar" => 20})
  end

  def elem(name, weight)
    if name.nil?
      elem_weight(weight)
    else
      {"weight"=>weight, "name"=>name}
    end
  end

  def elem_weight(weight)
    {"weight"=>weight}
  end

  def complex_elem(name, weight, str_map_key, str_map_value)
    {"name" => name, "weight" => weight, "str_map" => {str_map_key => str_map_value}}
  end

  def run_baseline_test_case
    feed(:file => selfdir + "docs.json")
    assert_document(@default_array, @default_map, @default_str_int_map)
    assert_result(@default_array, @default_map, @default_str_int_map)
  end
  
  def run_test_case(file_name, exp_elem_array, exp_elem_map, exp_str_int_map, route_search_direct = false)
    run_baseline_test_case
    if (route_search_direct)
      feed(:file => selfdir + file_name, :route => "search-direct")
    else
      feed(:file => selfdir + file_name)
    end
    assert_document(exp_elem_array, exp_elem_map, exp_str_int_map)
    assert_result(exp_elem_array, exp_elem_map, exp_str_int_map)
  end

  def routing_variants
    if is_streaming
      [ false ]
    else
      [ true, false ]
    end
  end

  def run_test_cases(file_name, exp_elem_array, exp_elem_map, exp_str_int_map)
    routing_variants.each { |direct_route| run_test_case(file_name, exp_elem_array, exp_elem_map, exp_str_int_map, direct_route) }
  end

  def assert_document(exp_elem_array, exp_elem_map, exp_str_int_map)
    response = @http.get("/document/v1/test/test/docid/0")
    doc = JSON.parse(response.body)
    puts "assert_document(): doc:        #{doc}"
    elem_array = doc["fields"]["elem_array"]
    elem_map = doc["fields"]["elem_map"]
    str_int_map = doc["fields"]["str_int_map"]
    puts "assert_document(): elem_array:  #{elem_array}"
    puts "assert_document(): elem_map:    #{elem_map}"
    puts "assert_document(): str_int_map: #{str_int_map}"

    assert_equal(exp_elem_array, elem_array)
    assert_equal(exp_elem_map, elem_map)
    assert_equal(exp_str_int_map, str_int_map)
  end

  def assert_result(exp_elem_array, exp_elem_map, exp_str_int_map)
    result = search("query=sddocname:test&streaming.selection=true&presentation.format=json")
    assert_equal(1, result.hitcount)
    hit = result.hit[0]
    elem_array = hit.field["elem_array"]
    elem_map = hit.field["elem_map"]
    str_int_map = hit.field["str_int_map"]
    summary_features = hit.field["summaryfeatures"]
    puts "assert_result(): elem_array:      #{elem_array}"
    puts "assert_result(): elem_map:        #{elem_map}"
    puts "assert_result(): str_int_map:     #{str_int_map}"
    puts "assert_result(): summaryfeatures: #{hit.field['summaryfeatures']}"

    assert_equal(exp_elem_array, elem_array)
    assert_equal(exp_elem_map, elem_map)
    assert_equal(exp_str_int_map, str_int_map)
    if @has_summary_features
      assert_summary_features(exp_elem_array, exp_elem_map, exp_str_int_map, summary_features)
    end
  end

  def assert_summary_features(exp_elem_array, exp_elem_map, exp_str_int_map, features)
    assert_equal(exp_elem_array, convert_features_to_array(features))
    assert_equal(exp_elem_map, convert_features_to_elem_map(features))
    assert_equal(exp_str_int_map, convert_features_to_str_int_map(features))
  end

  def convert_features_to_array(features)
    name_array = convert_string_features_to_array("elem_array.name", features)
    weight_array = convert_int_features_to_array("elem_array.weight", features)
    assert_equal(name_array.size, weight_array.size)
    if name_array.size == 0
      return nil
    end
    result = []
    for i in 0...name_array.size
      result.push(elem(name_array[i], weight_array[i]))
    end
    result
  end

  def convert_features_to_elem_map(features)
    key_array = convert_string_features_to_array("elem_map.key", features)
    name_array = convert_string_features_to_array("elem_map.value.name", features)
    weight_array = convert_int_features_to_array("elem_map.value.weight", features)
    assert_equal(key_array.size, name_array.size)
    assert_equal(key_array.size, weight_array.size)
    if key_array.size == 0
      return nil
    end
    result = {}
    for i in 0...key_array.size
      result[key_array[i]] = elem(name_array[i], weight_array[i])
    end
    result
  end

  def convert_features_to_str_int_map(features)
    key_array = convert_string_features_to_array("str_int_map.key", features)
    value_array = convert_int_features_to_array("str_int_map.value", features)
    assert_equal(key_array.size, value_array.size)
    if key_array.size == 0
      return nil
    end
    result = {}
    for i in 0...key_array.size
      result[key_array[i]] = value_array[i]
    end
    result
  end

  def convert_string_features_to_array(attr_name, features)
    size = features["attribute(#{attr_name}).count"].to_i
    result = []
    for i in 0...size do
      hash_val = features["attribute(#{attr_name},#{i})"].to_i
      result.push(convert_hash_to_string(hash_val))
    end
    puts "convert_string_features_to_array(#{attr_name}): #{result}"
    result
  end

  def convert_hash_to_string(hash)
    {101574 => "foo", 97299 => "bar", 97307 => "baz", 2008198 => "@foo", 2003923 => "@bar", 2003931 => "@baz"}[hash]
  end

  def convert_int_features_to_array(attr_name, features)
    size = features["attribute(#{attr_name}).count"].to_i
    result = []
    for i in 0...size do
      result.push(features["attribute(#{attr_name},#{i})"].to_i)
    end
    puts "convert_int_features_to_array(#{attr_name}): #{result}"
    result
  end

  def teardown
    stop
  end
end
