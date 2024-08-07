# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class VisitNullValues < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Visit documents that has an undefined field")
  end

  def test_visit_undefined
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed(:file => selfdir + "data.json", :timeout => 240)
    vespa.storage["storage"].assert_document_count(11)

    # Data is 10 documents with no fields set, or explicitly set to a
    # value that behaves as undefined (see ./data.json), and 1 document
    # with all fields set.
    @documents = 11

    # Feeding undefined value has no effect unless attribute.
    assert_visit_null('test.integer_summary', 9)

    expected_fields_with_null_value = is_streaming ? 9 : 10
    assert_visit_null('test.integer_attribute', expected_fields_with_null_value)
    assert_visit_null('test.string_index', 10)
    assert_visit_null('test.string_attribute', 10)
    assert_visit_null('test.string_array_index', 10)
    assert_visit_null('test.string_array_attribute', 10)
  end

  def assert_visit_null(field, null_count)
    assert_visit(field + ' == null', null_count)
    assert_visit(field + ' != null', @documents - null_count)
  end

  def assert_visit(select_expr, result_count)
    count = vespa.adminserver.
      execute("vespa-visit -s '" + select_expr + "' -i | wc -l").to_i
    assert_equal(result_count, count)
  end

  def teardown
    stop
  end

end
