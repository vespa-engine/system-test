# Copyright 2020 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class BoolTypeTest < SearchTest

  def setup
    set_owner("geirst")
  end

  def test_bool_attribute_search
    set_description("Test search on attributes of type 'bool'")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed(:file => selfdir + "docs.json")

    assert_hits([0, 2], "b1 = false")
    assert_hits([1, 3], "b1 = true")
    assert_hits([0, 1], "b2 = false")
    assert_hits([2, 3], "b2 = true")

    assert_hits([0], "b1 = false and b2 = false")
    assert_hits([1], "b1 = true and b2 = false")
    assert_hits([2], "b1 = false and b2 = true")
    assert_hits([3], "b1 = true and b2 = true")

    assert_hits([1], "!(b1 = false) and b2 = false")
    assert_hits([0], "!(b1 = true) and b2 = false")
    assert_hits([3], "!(b1 = false) and b2 = true")
    assert_hits([2], "!(b1 = true) and b2 = true")
  end

  def assert_hits(exp_docids, expr)
    query = get_query(expr)
    puts "assert_hits(#{exp_docids}): query='#{query}'"
    result = search(query)
    result.sort_results_by("documentid")
    assert_hitcount(result, exp_docids.size)
    for i in 0...exp_docids.size
      docid = get_docid(exp_docids[i])
      assert_field_value(result, "documentid", docid, i)
    end
  end

  def get_query(expr)
    "yql=select %2a from sources %2a where " + expr + "%3b"
  end

  def get_docid(id)
    "id:test:test::#{id}"
  end

  def teardown
    stop
  end

end
