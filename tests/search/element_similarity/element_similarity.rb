# Copyright Vespa.ai. All rights reserved.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class ElementSimilarity < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def make_query(field, terms)
    query = "query=select+%2a+from+sources+%2a+where+%28"
    terms.each_with_index do |term, i|
      if i > 0
        query += "+OR+";
      end
      query += "#{field}+contains+%22#{term}%22"
    end
    query += "%29%3B&type=yql";
  end

  def test_element_similarity
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")
    query = make_query("foo", ["a", "b", "c", "d", "e"])
    puts "query: '#{query}'"
    result = search(query)
    assert(result.hit.size == 1)
    rf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures: '#{rf}'"
    json = rf
    assert_features({"elementSimilarity(foo)" => 15.0 }, json)
  end

  def teardown
    stop
  end

end
