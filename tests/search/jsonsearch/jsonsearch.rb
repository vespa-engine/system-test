# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'
require 'json'

class JsonSearch < IndexedStreamingSearchTest

  def setup
    set_owner("valerijf")
    set_description("Test basic searching and feeding with JSON")
  end

  def test_jsonsearch
    deploy_app(SearchApp.new.
               cluster_name("basicsearch").
               sd(SEARCH_DATA+"music.sd"))
    start
    feed(:file => SEARCH_DATA+"music.10.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=country", 1)
    assert_hitcount("query=title:country", 1)
    assert_hitcount("query=mid:2", 10)
    assert_hitcount("query=sddocname:music", 10)
    result = search("/search/?query=sddocname:music&format=json&sorting=surl&hits=3")
    tree = JSON.parse(result.xmldata)
    assert_equal("http://shopping.yahoo.com/shop?d=hab&id=1804905709", tree["root"]["children"][0]["fields"]["surl"])
    assert_equal("http://shopping.yahoo.com/shop?d=hab&id=1804905710", tree["root"]["children"][1]["fields"]["surl"])
    assert_equal("http://shopping.yahoo.com/shop?d=hab&id=1804905711", tree["root"]["children"][2]["fields"]["surl"])
  end

  def teardown
    stop
  end

end
