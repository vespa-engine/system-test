# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_search_test'

class Embedding < IndexedSearchTest

  def setup
    set_owner("bratseth")
  end

  def test_embedding
    deploy(selfdir + "app/")
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")
    result = search("yql%3Dselect%20*%20from%20source%20doc%20where%20sddocname%20contains%20%27doc%27%26ranking.feature.query(encode(hello%20world))")
    assert(result.hit.size == 3)
    hit0 = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{hit0}'"
    json0 = JSON.parse(hit0)
    # assert_features({"query(embedding)" => ... }, json0)
    # assert_features({"attribute(embedding)" => ... }, json0)
    hit1 = result.hit[1].field["summaryfeatures"]
    puts "summaryfeatures: '#{hit1}'"
    json = JSON.parse(hit1)
    # assert_features({"query(embedding)" => ... }, json1)
    # assert_features({"attribute(embedding)" => ... }, json1)
  end

  def teardown
    stop
  end

end
