# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class CharEncoding < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Text character encoding, for data that does not 'normalize' accents")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def test_char_encoding
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")

    regexp = /surl/
    puts "Query: Searching for 'walkuere'"
    assert_hitcount("query=walkuere", 0)

    puts "Query: Searching for 'walküre'"
    assert_result_matches("query=walk%c3%bcre", selfdir+"walkure_u_umlaut.result", regexp, true)

    puts "Query: Searching for 'WALKÜRE'"
    assert_result_matches("query=WALK%C3%9CRE", selfdir+"walkure_u_umlaut.result", regexp, true)

    puts "Query: Searching for 'espana'"
    assert_result_matches("query=espana", selfdir+"espana_n.result", regexp, true)

    puts "Query: Searching for 'españa'"
    assert_result_matches("query=espa%c3%b1a", selfdir+"espana_n_tilde.result", regexp, true)

    puts "Query: Searching for 'ESPAÑA'"
    assert_result_matches("query=ESPA%C3%91A", selfdir+"espana_n_tilde.result", regexp, true)

    puts "Query: Searching for 'francois'"
    assert_result_matches("query=francois", selfdir+"francois_c.result", regexp, true)

    puts "Query: Searching for 'françois'"
    assert_result_matches("query=fran%c3%a7ois", selfdir+"francois_c_cedilla.result", regexp, true)

    puts "Query: Searching for 'FRANÇOIS'"
    assert_result_matches("query=FRAN%C3%87OIS", selfdir+"francois_c_cedilla.result", regexp, true)

  end

  def teardown
    stop
  end

end
