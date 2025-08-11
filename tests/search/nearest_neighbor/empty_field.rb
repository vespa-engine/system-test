# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class EmptyFieldTest < IndexedStreamingSearchTest

  def setup
    set_owner("boeker")
  end

  def test_empty_field_single_vector
    set_description("Test the behavior of the nearest neighbor search operator for an empty tensor field with a single vector")
    schema_name = "singlevec"
    vector0 = [0,0]
    vector1 = [1,1]
    vector2 = [2,2]

    empty_field_test(schema_name, vector0, vector1, vector2)
  end

  def test_empty_field_multiple_vectors
    set_description("Test the behavior of the nearest neighbor search operator for an empty tensor field with multiples vector")
    schema_name = "multivec"
    vector0 = [{'address'=>{'x'=>'a', 'y'=>'0'}, 'value'=>0},
               {'address'=>{'x'=>'a', 'y'=>'1'}, 'value'=>0},
               {'address'=>{'x'=>'b', 'y'=>'0'}, 'value'=>5},
               {'address'=>{'x'=>'b', 'y'=>'1'}, 'value'=>5}]
    vector1 = [{'address'=>{'x'=>'a', 'y'=>'0'}, 'value'=>1},
               {'address'=>{'x'=>'a', 'y'=>'1'}, 'value'=>1},
               {'address'=>{'x'=>'b', 'y'=>'0'}, 'value'=>6},
               {'address'=>{'x'=>'b', 'y'=>'1'}, 'value'=>6}]
    vector2 = [{'address'=>{'x'=>'a', 'y'=>'0'}, 'value'=>2},
               {'address'=>{'x'=>'a', 'y'=>'1'}, 'value'=>2},
               {'address'=>{'x'=>'b', 'y'=>'0'}, 'value'=>7},
               {'address'=>{'x'=>'b', 'y'=>'1'}, 'value'=>7}]

    empty_field_test(schema_name, vector0, vector1, vector2)
  end

  def empty_field_test(schema_name, vector0, vector1, vector2)
    sd_file = selfdir + "empty_field/#{schema_name}.sd"
    deploy_app(SearchApp.new.sd(sd_file))
    start

    # Feed document that misses the "tensor2" field
    doc = Document.new("id:test:#{schema_name}::0")
                  .add_field("docid", "0")
                  .add_field("tensor1", vector0)
    vespa.document_api_v1.put(doc)

    # Feed document that has both tensor fields
    doc = Document.new("id:test:#{schema_name}::1")
                  .add_field("docid", "1")
                  .add_field("tensor1", vector1)
                  .add_field("tensor2", vector2)
    vespa.document_api_v1.put(doc)

    wait_for_hitcount("?query=sddocname:#{schema_name}", 2)

    puts "Query with HNSW"
    query = "yql=select * from #{schema_name} where {targetHits:10, approximate:true}nearestNeighbor(tensor2, query_vector)&input.query(query_vector)=[1,1]&ranking.matching.approximateThreshold=0.00"
    puts query
    result = search(query)
    puts "#{result.hitcount} hits"
    assert_equal(1, result.hitcount)

    puts "Query with exact search"
    query = "yql=select * from #{schema_name} where {targetHits:10, approximate:false}nearestNeighbor(tensor2, query_vector)&input.query(query_vector)=[1,1]"
    puts query
    result = search(query)
    puts "#{result.hitcount} hits"
    assert_equal(1, result.hitcount)
  end

  def teardown
    stop
  end
end
