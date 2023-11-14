# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class IntegerSearch < IndexedSearchTest

  # Description: Various searches for integers, ranges and single
  # Component: Search
  # Feature: Query functionality

  def setup
    set_owner("yngve")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    start
  end

  def compare(query, file, field)
    assert_field(query, selfdir+file, field, true)
  end

  def test_integersearch
    feed_and_wait_for_docs("simple", 15, :file => selfdir+"some.xml", :exceptiononfailure => false)

    # Query: sanity check
    assert_hitcount("query=sddocname:simple", 15)

    # single years
    assert_hitcount("query=year:0", 1)
    assert_hitcount("query=year:1969", 1)
    assert_hitcount("query=year:1974", 2)
    assert_hitcount("query=year:1975", 1)
    assert_hitcount("query=year:2147483647", 1)
    assert_hitcount("query=year:-2147483647", 1)
    assert_hitcount("query=year:-1", 1)

    # Query: range of years
    compare("query=year:[1970%3B1975]&sorting=year", "q3.result", "uri")
    assert_hitcount("query=year:[0%3B2147483647]&sorting=year", 10)
    assert_hitcount("query=year:[-2147483647%3B0]&sorting=year", 3)

    # Query: range of years - single year in range
    compare("query=year:[1970%3B1975]%20-year:1972&sorting=year", "q4.result", "uri")

    # Query: yql year range using ># and <# with sorting in yql
    compare("query=select%20%2A%20from%20sources%20%2A%20where%20%28year%20%3E%201969%20AND%20year%20%3C%201976%29%20order%20by%20year%3B&type=yql", "q3.result", "uri")
  end

  def teardown
    stop
  end

end
