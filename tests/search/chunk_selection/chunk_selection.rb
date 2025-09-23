# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class ChunkSelectionTest < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_chunk_selection
    set_description("Test selecting which chunks to return based on per-chunk scoring")
    sd_file = selfdir + "test.sd"
    deploy_app(SearchApp.new.sd(sd_file).threads_per_search(1))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")
    query = "yql=select * from sources * where rank (true, text contains 'e')"
    query += "&ranking.features.query(qpos)=[15,10]"
    result = search(query)
    puts JSON.pretty_generate(JSON.parse(result.to_s))
    assert_equal(result.hitcount, 1)
    assert_equal(result.hit[0].field["text"].size, 1)
    assert_equal(result.hit[0].field["text"][0], "d e f")
  end

end
