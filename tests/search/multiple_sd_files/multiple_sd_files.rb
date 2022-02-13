# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MultipleSdFiles < IndexedSearchTest

  def setup
    set_owner("musum")
    set_description("Test that its possible to have two search definitions in a cluster")
  end

  def test_search_two_searchdefs
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").sd((selfdir+"attributefilter.sd")))
    start
    feed_and_wait_for_docs("music", 10, :file => "#{SEARCH_DATA}/music.10.xml")
    assert_result("query=sddocname:music", "#{SEARCH_DATA}/music.10.nouri.result.json", "title", ["title", "surl", "mid", "sddocname"])
    assert(JSON.generate(getvespaconfig("document.config.documentmanager", "client")) =~ /"name":"attributefilter",/)
  end

  def teardown
    stop
  end

end
