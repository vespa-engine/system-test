# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Default_Index < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Verify that default index is used if not explicitly stated.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_default_index
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.xml")

    filterexp = /total-hit-count|"surl"/

    puts "Query: Search specifying default index explicitly"
    assert_result_matches("query=default:cadillac", selfdir + "cadillac_defaultindex.result", filterexp, true)

    puts "Query: Search to default index"
    assert_result_matches("query=cadillac", selfdir + "cadillac_defaultindex.result", filterexp, true)

    puts "Query: Search to an explicit index different from default"
    assert_result_matches("query=song:cadillac", selfdir + "cadillac_song_index.result", filterexp, true)
  end

  def teardown
    stop
  end

end
