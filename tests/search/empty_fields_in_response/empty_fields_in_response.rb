# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class EmptyFieldsInResponseTest < IndexedStreamingSearchTest

  def setup
    set_owner("lesters")
    set_description("Test empty single- and multivalued fields in search and get")
  end

  def self.final_test_methods
    [ "test_empty_reference_field_in_search_and_get_response" ]
  end

  def test_empty_fields_in_search_and_get_response
    @doctype = 'test'
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").enable_document_api)
    start
    feed_and_wait_for_docs("test", 4, :file => selfdir + "docs.json")
    assert_search
    assert_get
  end

  def test_empty_reference_field_in_search_and_get_response
    @doctype = 'child'
    @params = { :search_type => "ELASTIC" }
    deploy_app(SearchApp.new.sd(selfdir+"child.sd").sd(selfdir + "parent.sd", { :global => true }).enable_document_api)
    start
    feed_and_wait_for_docs("child", 4, :file => selfdir + "child_docs.json")
    assert_search
    assert_get
  end

  def normal_values
    {
      "int_attribute" => 42,
      "int_non_attribute" => 144,
      "long_attribute" => 42,
      "long_non_attribute" => 144,
      "byte_attribute" => 42,
      "byte_non_attribute" => 44,
      "bool_attribute" => true,
      "bool_non_attribute" => true,
      "float_attribute" => 42.0,
      "float_non_attribute" => 144.0,
      "double_attribute" => 42.0,
      "double_non_attribute" => 144.0,
      "string_attribute" => "a string value",
      "string_non_attribute" => "a string value",
      "array_attribute" => [42, 144],
      "array_non_attribute" => [42, 144],
      "weightedset_attribute" => { "a" => 1 },
      "weightedset_non_attribute" => { "a" => 1 },
      "map_attribute" => { "b" => 2 },
      "map_non_attribute" => { "b" => 2 },
      "tensor_attribute"  => {
        "type" => "tensor(x{},y{})",
        "cells" => [
          { "address" => { "x" => "a", "y" => "b" }, "value" => 2.0 },
          { "address" => { "x" => "c", "y" => "d" }, "value" => 3.0 }
        ]
      },
      "tensor_non_attribute" => {
        "type" => "tensor(x{},y{})",
        "cells" => [
          { "address" => { "x" => "a", "y" => "b" }, "value" => 12.0 },
          { "address" => { "x" => "c", "y" => "d" }, "value" => 13.0 }
        ]
      },
      "reference_attribute" => "id:test:parent::normal"
    }
  end

  def not_set_search_values
    if is_streaming
      {
        # Bool has no empty value. Always present in docsum blob.
        "bool_attribute" => false,
        "bool_non_attribute" => false
      }
    else
      {
        # Bool has no empty value. Always present in attribute.
        "bool_attribute" => false
      }
    end
  end

  def set_null_search_values
    not_set_search_values
  end

  def set_empty_search_values
    not_set_search_values
  end

  def not_set_get_values
    if is_streaming
      {
      }
    else
      {
        # Bool has no empty value. Always present in attribute.
        "bool_attribute" => false
      }
    end
  end

  def set_null_get_values
    not_set_get_values
  end

  def set_empty_get_values
    if is_streaming
      {
        "int_attribute" => -2147483648,
        "int_non_attribute" => -2147483648,
        "long_attribute" => -9223372036854775808,
        "long_non_attribute" => -9223372036854775808,
        "byte_attribute" => -128,
        "byte_non_attribute" => -128
      }
    else
      {
        "int_non_attribute" => -2147483648,
        "long_non_attribute" => -9223372036854775808,
        "byte_non_attribute" => -128,
        # Bool has no empty value. Always present in attribute.
        "bool_attribute" => false,
        # Reference attribute has no empty value
        "reference_attribute" => ""
      }
    end
  end

  def assert_search()
    result = search("query=sddocname:#{@doctype}&streaming.selection=true")
    assert(result.hit.size == 4)
    assert_fields(find_doc(result, "normal"), "find", "normal", :get_search_field_value, normal_values)
    assert_fields(find_doc(result, "not_set"), "find", "not_set", :get_search_field_value, not_set_search_values)
    assert_fields(find_doc(result, "set_null"), "find", "set_null", :get_search_field_value, set_null_search_values)
    assert_fields(find_doc(result, "set_empty"), "find", "set_empty", :get_search_field_value, set_empty_search_values)
  end

  def assert_get()
    assert_fields(get_doc("normal"), "get", "normal", :get_document_field_value, normal_values)
    assert_fields(get_doc("not_set"), "get", "not_set", :get_document_field_value, not_set_get_values)
    assert_fields(get_doc("set_null"), "get", "set_null", :get_document_field_value, set_null_get_values)
    assert_fields(get_doc("set_empty"), "get", "set_empty", :get_document_field_value, set_empty_get_values)
  end

  def find_doc(result, id)
    result.hit.each do |hit|
      if hit.field["documentid"] == ("id:test:#{@doctype}::" + id)
        return hit
      end
    end
    assert(false, "Hit with id " + id + " not found")
  end

  def get_doc(id)
    return vespa.document_api_v1.get("id:test:#{@doctype}::" + id)
  end

  def assert_fields(hit, accessor, doc, get_fn, expected)
    fields = [
      "int_attribute",
      "int_non_attribute",
      "long_attribute",
      "long_non_attribute",
      "byte_attribute",
      "byte_non_attribute",
      "bool_attribute",
      "bool_non_attribute",
      "float_attribute",
      "float_non_attribute",
      "double_attribute",
      "double_non_attribute",
      "string_attribute",
      "string_non_attribute",
      "array_attribute",
      "array_non_attribute",
      "weightedset_attribute",
      "weightedset_non_attribute",
      "map_attribute",
      "map_non_attribute",
      "tensor_attribute",
      "tensor_non_attribute"
    ]
    fields = [ "reference_attribute" ] if @doctype == 'child'
    for field in fields
      begin
        assert_equal(expected[field], self.send(get_fn, hit, field))
      rescue Exception => e
        puts "Exception #{e.message} for #{accessor} #{doc}, #{field}"
        raise
      end
    end
  end

  def get_search_field_value(hit, field)
    return hit.field[field]
  end

  def get_document_field_value(hit, field)
      return hit.fields[field]
  end

  def teardown
    stop
  end

end

