# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Stemming < IndexedOnlySearchTest
  # No stemming in streaming search

  def setup
    set_owner("arnej")
    set_description("Test stemming (eg: car -> cars) with dictionary")
    # Explicitly use OpenNlpLinguistics to get the same results between public and internal system test runs.
    deploy_app(SearchApp.new.sd(selfdir + "music.sd").
               indexing_cluster("my-container").
               container(Container.new("my-container").
                         search(Searching.new).
                         documentapi(ContainerDocumentApi.new).
                         docproc(DocumentProcessing.new).
                         component(Component.new("com.yahoo.language.opennlp.OpenNlpLinguistics"))))
    start
  end

  def test_stemming
    # vespa.adminserver.logctl('container:com.yahoo.document', 'debug=on')
    sleep 2
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

    assert_hitcount("query=make+title:doc1&type=all", 1)
    assert_hitcount("query=make+title:doc2&type=all", 1)
    assert_hitcount("query=make+title:doc3&type=all", 0)
    assert_hitcount("query=make+title:doc10&type=all", 1)

    assert_hitcount("query=makes+title:doc1&type=all", 1)
    assert_hitcount("query=makes+title:doc2&type=all", 1)
    assert_hitcount("query=makes+title:doc3&type=all", 0)
    assert_hitcount("query=makes+title:doc10&type=all", 1)

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
    assert_hitcount("query=artist:the-bet-are-big", 1)
    assert_hitcount("query=artist:the-bets-are-big", 2)
  end


end
