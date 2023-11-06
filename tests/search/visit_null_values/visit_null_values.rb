# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class VisitNullValues < SearchTest

  def setup
    set_owner("geirst")
    set_description("Visit documents that has an undefined field")
  end

  def test_visit_undefined
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed(:file => selfdir + "data.xml", :timeout => 240)
    vespa.storage["storage"].assert_document_count(11)

    # Data is 10 documents with no fields set, or explicitly set to a
    # value that behaves as undefined (see ./data.xml), and 1 document
    # with all fields set.

    # Feeding undefined value has no effect unless attribute.
    assert_visit_null('test.integer_summary', 9, 2)

    assert_visit_null('test.integer_attribute', 10, 1)
    assert_visit_null('test.string_index', 10, 1)
    assert_visit_null('test.string_attribute', 10, 1)
    assert_visit_null('test.string_array_index', 10, 1)
    assert_visit_null('test.string_array_attribute', 10, 1)
  end

  def assert_visit_null(field, null_count, non_null_count)
    assert_visit(field + ' == null', null_count)
    assert_visit(field + ' != null', non_null_count)
  end

  def assert_visit(select_expr, result_count)
    count = vespa.adminserver.
      execute("vespa-visit -s '" + select_expr + "' -i | wc -l", :nostderr => true).to_i
    assert_equal(result_count, count)
  end

  def teardown
    stop
  end

end
