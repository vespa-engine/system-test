# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_search_test'

class ElementCompleteness < IndexedSearchTest

  def setup
    set_owner("bratseth")
  end

  def test_elementcompleteness
    deploy(selfdir + "app/")
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")
    result = search("yql%3Dselect%20*%20from%20source%20doc%20where%20sddocname%20contains%20%27doc%27%26ranking.feature.query(encode(hello%20world))")
    assert(result.hit.size == 3)
    hit0 = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{hit0}'"
    json = JSON.parse(rf)
    # assert_features({"query(embedding)" => ... }, json)
    # assert_features({"attribute(embedding)" => ... }, json)
    hit0 = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{hit0}'"
    json = JSON.parse(rf)
    # assert_features({"query(embedding)" => ... }, json)
    # assert_features({"attribute(embedding)" => ... }, json)
  end

  def sentencepiece_config
    ConfigOverride.new("language.sentencepiece.sentence-piece").
      add(ArrayConfig.new("model").append.
                                   add(0, ConfigValue.new("language", "unknown")).
                                   add(0, ConfigValue.new("path", "model/en.wiki.bpe.vs10000.model")))
  end

  def teardown
    stop
  end

end
