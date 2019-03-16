# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class EmptyFieldsInResponseTest < IndexedSearchTest

  def setup
    set_owner("lesters")
    set_description("Test empty single- and multivalued fields in search and get")
  end

  def test_empty_fields_in_search_and_get_response
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").enable_http_gateway)
    start
    feed_and_wait_for_docs("test", 4, :file => selfdir + "docs.json", :json => true)
    assert_search
    assert_get
  end

  def assert_search()
    result = search("query=sddocname:test")
    assert(result.hit.size == 4)
    assert_fields(find_doc(result, "normal"), :get_search_field_value, :assert_not_equal, nil)
    assert_fields(find_doc(result, "not_set"), :get_search_field_value, :assert_equal, nil)
    assert_fields(find_doc(result, "set_null"), :get_search_field_value, :assert_equal, nil)
    assert_fields(find_doc(result, "set_empty"), :get_search_field_value, :assert_equal, nil)
  end

  def assert_get()
    assert_fields(get_doc("normal"), :get_document_field_value, :assert_not_equal, nil)
    assert_fields(get_doc("not_set"), :get_document_field_value, :assert_equal, nil)
    assert_fields(get_doc("set_null"), :get_document_field_value, :assert_equal, nil)
    # known exception: reserved code for empty int fields will be returned for non-attributes
    assert_fields(get_doc("set_empty"), :get_document_field_value, :assert_equal, nil, ["int_non_attribute"])
  end

  def find_doc(result, id)
    result.hit.each do |hit|
      if hit.field["documentid"] == ("id:test:test::" + id)
        return hit
      end
    end
    assert(false, "Hit with id " + id + " not found")
  end

  def get_doc(id)
    return vespa.document_api_v1.get("id:test:test::" + id)
  end

  def assert_fields(hit, get_fn, assert_fn, expected = nil, skip_fields = [])
    fields = [
      "int_attribute",
      "int_non_attribute",
      "string_attribute",
      "string_non_attribute",
      "array_attribute",
      "array_non_attribute",
      "weightedset_attribute",
      "weightedset_non_attribute",
      "map_attribute",
      "map_non_attribute"
    ]
    for field in fields
      if !(skip_fields.include? field)
        self.send(assert_fn, expected, self.send(get_fn, hit, field))
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

