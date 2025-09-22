# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Stemming < IndexedOnlySearchTest
  # No stemming in streaming search

  def setup
    set_owner("geirst")
    set_description("Test stemming (eg: car -> cars) with dictionary")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def test_stemming
    feed_and_wait_for_docs("music", 10, :file => selfdir+"stemming.10.json")

    wait_for_hitcount("query=war", 3)
    puts "Query: testing singular and plural"
    assert_hitcount("query=war", 3)
    assert_hitcount("query=wars", 3)
    assert_hitcount("query=car", 7)
    assert_hitcount("query=cars", 7)

    puts "Query: testing verb forms"
    assert_hitcount("query=make", 3)
    assert_hitcount("query=makes", 3)
    assert_hitcount("query=makes&language=pt", 1)

    assert_hitcount("query=artist:towers", 2)
    assert_hitcount("query=artist:tower", 2)

    assert_hitcount("query=artist:christmas", 3)
    assert_hitcount("query=artist:Christmas", 3)
    assert_hitcount("query=artist:CHRISTMAS", 3)

    assert_hitcount("query=artist:inxs", 3)
    assert_hitcount("query=artist:Inxs", 3)
    assert_hitcount("query=artist:INXS", 3)

    assert_hitcount("query=artist:%22towers of power", 2)
    assert_hitcount("query=artist:bet", 3)
    assert_hitcount("query=artist:bets", 4)
    assert_hitcount("query=artist:the-bets-are-big", 2)
    assert_hitcount("query=artist:the-bet-are-big", 1)
  end

  def teardown
    stop
  end

end
