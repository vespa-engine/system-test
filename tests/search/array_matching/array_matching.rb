# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ArrayMatching < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_array_match
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "feed.xml")
    assert_hitcount("/search/?yql=select%20%2A%20from%20sources%20%2A%20where%20IDs%20contains%20%221%22%20AND%20IDs%20contains%20%225%22%3B", 1)
    assert_hitcount("/search/?yql=select%20%2A%20from%20sources%20%2A%20where%20IDs%20contains%20%221%22%20OR%20IDs%20contains%20%225%22%3B", 5)
    assert_hitcount("/?query=IDs:1%20IDs:5&type=all", 1)
    assert_hitcount("/?query=(IDs:1%20IDs:5)&type=all", 5)
    result = search("/?query=(IDs:1!200%20IDs:2%20IDs:3%20IDs:4%20IDs:5)&hits=5&type=all");
    assert_equal(result.hit.size, 5)
    puts result.hit[0].field["relevancy"]
    puts result.hit[1].field["relevancy"]
    puts result.hit[2].field["relevancy"]
    puts result.hit[3].field["relevancy"]
    puts result.hit[4].field["relevancy"]
  end

  def teardown
    stop
  end

end
