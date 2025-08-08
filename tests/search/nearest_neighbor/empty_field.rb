# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class EmptyFieldTest < IndexedStreamingSearchTest

  def setup
    set_owner("boeker")
  end

  def test_empty_field
    set_description("Test the behavior of the nearest neighbor search operator for an empty tensor field")
    sd_file = selfdir + "empty_field/twotensors.sd"
    deploy_app(SearchApp.new.sd(sd_file))
    start

    # Feed document that misses the "tensor2" field
    doc = Document.new("id:test:twotensors::0")
                  .add_field("docid", "0")
                  .add_field("tensor1", [0,0])
    vespa.document_api_v1.put(doc)

    # Feed document that has both tensor fields
    doc = Document.new("id:test:twotensors::1")
                  .add_field("docid", "1")
                  .add_field("tensor1", [1,1])
                  .add_field("tensor2", [2,2])
    vespa.document_api_v1.put(doc)

    wait_for_hitcount('?query=sddocname:twotensors', 2)

    puts "Query with HNSW"
    query = "yql=select * from twotensors where {targetHits:10, approximate:true}nearestNeighbor(tensor2, query_vector)&input.query(query_vector)=[1,1]&ranking.matching.approximateThreshold=0.00"
    puts query
    result = search(query)
    puts "#{result.hitcount} hits"
    assert_equal(1, result.hitcount)

    puts "Query with exact search"
    query = "yql=select * from twotensors where {targetHits:10, approximate:false}nearestNeighbor(tensor2, query_vector)&input.query(query_vector)=[1,1]"
    puts query
    result = search(query)
    puts "#{result.hitcount} hits"
    assert_equal(1, result.hitcount)
  end

  def teardown
    stop
  end
end
