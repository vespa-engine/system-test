# Copyright 2020 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class BoolTypeTest < SearchTest

  def setup
    set_owner("geirst")
  end

  def test_bool_attribute_search
    set_description("Test search on attributes of type 'bool'")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    @doctype = "test"
    start
    feed(:file => selfdir + "docs.json")

    run_search_test
  end

  def test_imported_bool_attribute_search
    set_description("Test search on imported attributes of type 'bool'")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd", { :global => true }).sd(selfdir + "child.sd"))
    @doctype = "child"
    start
    feed(:file => selfdir + "docs.json")
    feed(:file => selfdir + "docs_child.json")

    run_search_test
  end

  def run_search_test
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
      assert_equal(docid, result.hit[i].field['documentid'])
    end
  end

  def get_query(expr)
    "yql=select %2a from sources %2a where " + expr + "&model.restrict=#{@doctype}"
  end

  def get_docid(id)
    "id:#{@doctype}:#{@doctype}::#{id}"
  end

  def teardown
    stop
  end

end
