# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class MultipleSdFiles < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test that its possible to have two search definitions in a cluster")
  end

  def test_search_two_searchdefs
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").sd((selfdir+"attributefilter.sd")))
    start
    feed_and_wait_for_docs("music", 10, :file => "#{SEARCH_DATA}/music.10.json")
    assert_result("query=sddocname:music", "#{SEARCH_DATA}/music.10.nouri.result.json", "title", ["title", "surl", "mid", "sddocname"])
    assert(JSON.generate(getvespaconfig("document.config.documentmanager", "client")) =~ /"name":"attributefilter",/)
  end


end
