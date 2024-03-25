# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class TextSimilarityFeature < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_text_similarity_feature
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28both%20contains%20%22a%22%20OR%20both%20contains%20%22b%22%20OR%20both%20contains%20%22c%22%20OR%20both%20contains%20%22d%22%20OR%20both%20contains%20%22e%22%29%3B&type=yql")
    assert(result.hit.size == 1)
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf

    assert_features({"textSimilarity(title).proximity" => 1.0}, json)
    assert_features({"textSimilarity(title).order" => 1.0}, json)
    assert_features({"textSimilarity(title).queryCoverage" => 0.8}, json)
    assert_features({"textSimilarity(title).fieldCoverage" => 1.0}, json)

    assert_features({"textSimilarity(body).proximity" => 0.75}, json)
    assert_features({"textSimilarity(body).order" => 0.75}, json)
    assert_features({"textSimilarity(body).queryCoverage" => 1.0}, json)
    assert_features({"textSimilarity(body).fieldCoverage" => 0.25}, json)

    assert(json["textSimilarity(title).score"] > 0.6)
    assert(json["textSimilarity(body).score"] > 0.6)
    assert(json["textSimilarity(title).score"] < 0.98)
    assert(json["textSimilarity(body).score"] < 0.98)

    assert(json["textSimilarity(body).score"] < json["textSimilarity(title).score"])
  end

  def teardown
    stop
  end

end
