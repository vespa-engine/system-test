# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Test_4_11 < IndexedSearchTest
  # Description: Field search for text and string, and range search for integers
  # Component: Search
  # Feature: Query functionality

  def setup
    set_owner("yngve")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_4_11
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")

    filter = Regexp.new("total-hit-count|\"surl\"")

    # Query: rock + range of years
    assert_result_matches("query=rock%20year:[1999%3B2002]&hits=100", selfdir + "4.11_1.result", filter, true)

    # Query: range of years - single year in range
    assert_result_matches("query=year:[1970%3B1973]%20-year:1972&hits=100", selfdir + "4.11_2.result", filter, true)

    # Query: rock - rock in title"
    assert_result_matches("query=rock%20-title:rock&hits=100", selfdir + "4.11_3.result", filter, true)

    # Query: yellow in song - yellow in title"
    assert_result_matches("query=song:yellow%20-title:yellow", selfdir + "4.11_4.result", filter, true)

    # Query: yql year range using ># and <#"
    assert_result_matches("query=select+%2A+from+sources+%2A+where+year+%3E+0%20and%20year+%3C+1930%3B&type=yql", selfdir + "4.11_5.result", filter, true)

    # Query: as previous query but using [# ; #]"
    assert_result_matches("query=year:[1%3B1929]", selfdir + "4.11_6.result", filter, true)

    # Query: searching for integer in text-fields"
    assert_result_matches("query=title:101%20-song:101", selfdir + "4.11_7.result", filter, true)
  end

  def teardown
    stop
  end

end
