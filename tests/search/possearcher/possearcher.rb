# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class PosSearcher < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Test that we can plug in position searcher")
  end

  def test_pos_searcher
    deploy_app(SearchApp.new.sd(selfdir+"local.sd"))
    start
    feed_and_wait_for_docs("local", 12, :file => selfdir+"docs.json")
    wait_for_hitcount("query=BP", 1)
    puts "Query: Search with position"
    assert_hitcount("query=BP&pos.ll=0N%3B0E", 0)
    assert_hitcount("query=BP&pos.ll=63N25%3B10E25", 1)
    assert_hitcount("query=BP&pos.ll=63N25%3B10E25&pos.attribute=ll", 1)

    assert_hitcount("query=sddocname:local&pos.ll=63.4225N%3B10.3637E", 10)
    assert_hitcount("query=sddocname:local&pos.ll=63.4225N%3B10.3637E&pos.radius=5km", 6)
    assert_hitcount("query=sddocname:local&pos.ll=63.4225N%3B10.3637E&pos.radius=100m", 1)

    result = search("query=sddocname:local&pos.ll=63.4225N%3B10.3637E&pos.xy=0%3B0")
    assert(result.xmldata.include?("Cannot handle both lat/long and xy coords at the same time"))
  end

  def teardown
    stop
  end

end
