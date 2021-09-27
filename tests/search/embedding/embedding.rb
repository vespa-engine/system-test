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
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22%3B&ranking.features.query(embedding)=encode(Hello%20world)&format=json").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(embedding)"]
    attributeFeature = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding)"]
    puts "queryFeature: '#{queryFeature}'"
    puts "attributeFeature: '#{attributeFeature}'"
    expectedEmbedding = JSON.parse('{"type":"tensor(x[5])","cells":[{"address":{"x":"0"},"value":9912.0},{"address":{"x":"1"},"value":0.0},{"address":{"x":"2"},"value":6595.0},{"address":{"x":"3"},"value":501.0},{"address":{"x":"4"},"value":0.0}]}')
    assert_equal(expectedEmbedding.to_s, queryFeature.to_s)
    assert_equal(expectedEmbedding.to_s, attributeFeature.to_s)
  end

  def teardown
    stop
  end

end
