# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Bug6559464Test < IndexedStreamingSearchTest

  def setup
    set_owner('vekterli')
  end


  def test_default_get_is_merged_correctly_from_all_clusters
    deploy_app(SearchApp.new.
                 cluster(SearchCluster.new('musicsearch').sd(selfdir + 'application/schemas/music.sd')).
                 cluster(SearchCluster.new('booksearch').sd(selfdir + 'application/schemas/book.sd')).
                 cluster(SearchCluster.new('applesearch').sd(selfdir + 'application/schemas/apple.sd')))
    start

    feed(:file => selfdir + 'feed.json')

    puts "Get document with document v1 API"
    output = vespa.document_api_v1.http_get('/document/v1/music/music/docid/taz')
    puts output.body
    assert output.body =~ /Tasmanian Devil/

    puts("Attempting vespa-get of document which will fan out to all clusters " +
         "and only return a reply from one.")

    output = vespa.adminserver.execute("vespa-get 'id:music:music::taz'")
    assert output =~ /Tasmanian Devil/
  end

end
