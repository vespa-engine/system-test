# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class Default_Index < IndexedStreamingSearchTest

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
    assert_result("query=default:cadillac", selfdir + "cadillac_defaultindex.result.json", 'surl', [ 'surl' ])

    puts "Query: Search to default index"
    assert_result("query=cadillac", selfdir + "cadillac_defaultindex.result.json",  'surl', [ 'surl' ])

    puts "Query: Search to an explicit index different from default"
    assert_result("query=song:cadillac", selfdir + "cadillac_song_index.result.json",  'surl', [ 'surl' ])
  end

  def teardown
    stop
  end

end
