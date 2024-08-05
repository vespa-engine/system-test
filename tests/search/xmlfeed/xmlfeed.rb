# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class XmlFeed < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    set_description("Test feeding of xml (remove in Vespa 9)")
  end

  def test_basicsearch
    deploy_app(SearchApp.new.
               cluster_name("basicsearch").
               sd(SEARCH_DATA+"music.sd"))
    start

    # Explicitly test vespa-feeder
    feed(:file => selfdir + "music.10.xml", :client => :vespa_feeder)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=country", 1)
    assert_hitcount("query=country&ranking=unranked", 1)
    assert_hitcount("query=title:country", 1)
    assert_hitcount("query=mid:2", 10)
    assert_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=sddocname:music&ranking=unranked", 10)
    assert_result("query=sddocname:music",
                   SEARCH_DATA+"music.10.result.json",
                   "title", ["title", "surl", "mid"])
    assert_result("query=sddocname:music&ranking=unranked",
                   SEARCH_DATA+"music.10.result.json",
                   "title", ["title", "surl", "mid"])
  end

  def teardown
    stop
  end

end
