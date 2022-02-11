# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class LogicalIndexes < IndexedSearchTest

  def setup
    set_owner("bratseth")
    deploy_app(SearchApp.new.sd(selfdir+"type1.sd").sd(selfdir+"type2.sd"))
    start
  end

  def test_logicalindexes
    puts "Description: Test with logical indexes"
    puts "Component: Config, Indexing, Search etc"
    puts "Feature: Logical indexes"

    feed_and_wait_for_docs("type2", 1, :file => SEARCH_DATA+"testlogical.1.xml", :cluster => "logical")

    puts "Query: Second doctype"
    assert_result("query=f21d2&search=type2", selfdir + "type2.result.json")

    puts "Query: First doctype"
    assert_result("query=field12:f12d1&search=type1", selfdir + "type1.result.json")

    puts "Query: First doctype, with alias, should be the same"
    assert_result("query=felt12:f12d1&search=type1", selfdir + "type1.result.json")

    puts "Query: Mismatch fieldname/doctype -> no hits"
    assert_result("query=field13:23&search=type2", selfdir + "none.result.json")

    puts "Query: Both doctypes"
    assert_result("query=data", selfdir + "both.result.json", "sddocname")

    puts "Query: restrict to type1"
    assert_result("query=data&restrict=type1", selfdir + "type1.result.json")

    puts"Query: restrict to type2"
    assert_result("query=data&restrict=type2", selfdir + "type2.result.json")

  end

  def teardown
    stop
  end

end

