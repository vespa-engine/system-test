# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class StaticRank < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_staticrank
    set_description("Test for static rank")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.xml")

    puts "Search for year:1980, and see that results are sorted in order by decreasing weight"
    assert_result_matches("query=year:1980&hits=100&sortspec=-weight",
                          selfdir+"staticrank_year1980.result",
                          '<field name="weight">')

    puts "Search for year:1980, and see that results are sorted in order by static rank (weight)"
    assert_result_matches("query=year:1980&hits=100&sortspec=-[rank]",
                          selfdir+"staticrank_year1980.result",
                          '<field name="weight">')

    puts "Search for year:1980, and see that results are ranked in order by static rank (weight)"
    assert_result_matches("query=year:1980&hits=100",
                          selfdir+"staticrank_year1980.result",
                          '<field name="weight">')

    puts "Search for ew:love, and see that results are ranked in order by static rank (weight)"
    assert_result_matches("query=ew:love!0&hits=100",
                          selfdir+"staticrank_ew_love.result",
                          '<field name="weight">')

  end

  def test_update_rank
    set_description("Test that static rank can be updated")
    deploy_app(SearchApp.new.sd(selfdir+"updaterank.sd"))
    start
    feed_and_wait_for_docs("updaterank", 4, :file => selfdir+"updaterank0.xml")

    query_index = "query=indexfield:index&nocache"
    query_attribute = "query=attributefield:attribute&nocache"

    # ascending doc id
    assert_result(query_index, selfdir+"updaterank0.result", nil, ["body", "relevancy"])
    assert_result(query_attribute, selfdir+"updaterank0.result", nil, ["body", "relevancy"])

    # descending doc id
    feedfile(selfdir+"updaterank1.xml")
    wait_for_hitcount(query_index, 4);
    assert_result(query_index, selfdir+"updaterank1.result", nil, ["body", "relevancy"])
    assert_result(query_attribute, selfdir+"updaterank1.result", nil, ["body", "relevancy"])

    # ascending doc id
    feedfile(selfdir+"updaterank2.xml")
    wait_for_hitcount(query_index, 4);
    assert_result(query_index, selfdir+"updaterank0.result", nil, ["body", "relevancy"])
    assert_result(query_attribute, selfdir+"updaterank0.result", nil, ["body", "relevancy"])
  end

  def teardown
    stop
  end

end
