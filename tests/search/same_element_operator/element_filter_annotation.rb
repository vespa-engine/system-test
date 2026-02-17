# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

require 'json'

class ElementFilterAnnotation < IndexedStreamingSearchTest

  def setup
    set_owner('boeker')
    # This test uses the elementFilter annotation of the sameElement operator to limit it to specific ids,
    # effectively indexing the array at the specified positions.
  end

  def feed_docs(array_hash)
    # Get length of longest array
    max_length = 0
    array_hash.each do |name, arrays|
      max_length = [max_length, arrays.length].max
    end

    # Create array of documents
    docs = []
    (0...max_length).each do |i|
      docs.push(Document.new("id:arrays:arrays::#{i}").add_field("id", i))
    end

    # Add arrays to documents
    array_hash.each do |name, arrays|
      (0...arrays.length).each do |i|
        docs[i].add_field(name, arrays[i])
      end
    end

    # Feed documents
    docs.each do |doc|
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount("?query=sddocname:arrays", max_length)
  end


  def assert_docs(match_condition, expected_docids)
    query = {'yql' => "select * from sources * where #{match_condition} order by id asc"}
    result = search(query)
    assert_hitcount(result, expected_docids.length)
    for i in 0...expected_docids.length do
      assert_field_value(result, "documentid", "id:arrays:arrays::#{expected_docids[i]}", i)
    end
  end


  def test_bool_array
    set_description('Use elementFilter annotation of sameElement operator for indexing array of bools.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    feed_docs({"bool_array" => [[true, true, false], [false, false, true], [true, false, false], [false, true, false], [false, false, false]]})

    # Single element
    assert_docs("bool_array contains ({elementFilter:0}sameElement(\"true\"))", [0, 2])
    assert_docs("bool_array contains ({elementFilter:1}sameElement(\"true\"))", [0, 3])
    assert_docs("bool_array contains ({elementFilter:2}sameElement(\"true\"))", [1])
    assert_docs("bool_array contains ({elementFilter:3}sameElement(\"true\"))", [])

    assert_docs("bool_array contains ({elementFilter:0}sameElement(\"false\"))", [1, 3, 4])
    assert_docs("bool_array contains ({elementFilter:1}sameElement(\"false\"))", [1, 2, 4])
    assert_docs("bool_array contains ({elementFilter:2}sameElement(\"false\"))", [0, 2, 3, 4])
    assert_docs("bool_array contains ({elementFilter:3}sameElement(\"false\"))", [])

    # Multiple elements
    assert_docs("bool_array contains ({elementFilter:[0]}sameElement(\"true\"))", [0, 2])
    assert_docs("bool_array contains ({elementFilter:[0,1]}sameElement(\"true\"))", [0, 2, 3])
    assert_docs("bool_array contains ({elementFilter:[0,1,2]}sameElement(\"true\"))", [0, 1, 2, 3])
    assert_docs("bool_array contains ({elementFilter:[0,1,2,3]}sameElement(\"true\"))", [0, 1, 2, 3])
    assert_docs("bool_array contains ({elementFilter:[1,2,3]}sameElement(\"true\"))", [0, 1, 3])
    assert_docs("bool_array contains ({elementFilter:[2,3]}sameElement(\"true\"))", [1])
    assert_docs("bool_array contains ({elementFilter:[3]}sameElement(\"true\"))", [])

    assert_docs("bool_array contains ({elementFilter:[0,1,2,3]}sameElement(\"false\"))", [0, 1, 2, 3, 4])

    # Test wrong order and duplicated elements
    assert_docs("bool_array contains ({elementFilter:[0,0,0,0]}sameElement(\"true\"))", [0, 2])
    assert_docs("bool_array contains ({elementFilter:[25,25,25,0]}sameElement(\"true\"))", [0, 2])
  end


  def test_string_array
    set_description('Use elementFilter annotation of sameElement operator for indexing array of strings.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    feed_docs({"string_array" => [["foo", "bar", "baz"], ["foo", "bar", "bar"], ["foo", "foo", "foo"], ["bar", "bar", "foo"], ["baz", "baz", "baz"]]})

    # An empty list means "no filtering" and behaves as if no annotation is present.
    assert_docs("string_array contains sameElement(\"baz\")", [0, 4])
    assert_docs("string_array contains ({elementFilter:[]}sameElement(\"baz\"))", [0, 4])

    assert_docs("string_array contains ({elementFilter:0}sameElement(\"baz\"))", [4])
    assert_docs("string_array contains ({elementFilter:1}sameElement(\"baz\"))", [4])
    assert_docs("string_array contains ({elementFilter:2}sameElement(\"baz\"))", [0, 4])
    assert_docs("string_array contains ({elementFilter:3}sameElement(\"baz\"))", [])

    assert_docs("string_array contains ({elementFilter:[0]}sameElement(\"baz\"))", [4])
    assert_docs("string_array contains ({elementFilter:[0,1]}sameElement(\"baz\"))", [4])
    assert_docs("string_array contains ({elementFilter:[0,1,2]}sameElement(\"baz\"))", [0, 4])
    assert_docs("string_array contains ({elementFilter:[0,1,2,3]}sameElement(\"baz\"))", [0, 4])
    assert_docs("string_array contains ({elementFilter:[1,2,3]}sameElement(\"baz\"))", [0, 4])
    assert_docs("string_array contains ({elementFilter:[2,3]}sameElement(\"baz\"))", [0, 4])
    assert_docs("string_array contains ({elementFilter:[3]}sameElement(\"baz\"))", [])

    # Test wrong order and duplicated elements
    assert_docs("string_array contains ({elementFilter:[0,0,0,0]}sameElement(\"baz\"))", [4])
    assert_docs("string_array contains ({elementFilter:[25,25,25,0]}sameElement(\"baz\"))", [4])
  end


  def test_numerical_arrays
    set_description('Use elementFilter annotation of sameElement operator for indexing arrays of numbers.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    int_arrays = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [9, 5, 4], [9, 9, 9]]
    float_arrays = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0], [9.0, 5.0, 4.0], [9.0, 9.0, 9.0]]

    feed_docs({"byte_array" => int_arrays, "int_array" => int_arrays, "long_array" => int_arrays, "float_array" => float_arrays, "double_array" => float_arrays})

    ["byte_array", "int_array", "long_array"].each do |array_name|
      assert_docs("#{array_name} contains sameElement(\"9\")", [2, 3, 4])
      assert_docs("#{array_name} contains ({elementFilter:[]}sameElement(\"9\"))", [2, 3, 4])
    end

    ["byte_array", "int_array", "long_array"].each do |array_name|
      assert_docs("#{array_name} contains ({elementFilter:0}sameElement(\"1\"))", [0])
      assert_docs("#{array_name} contains ({elementFilter:1}sameElement(\"1\"))", [])
      assert_docs("#{array_name} contains ({elementFilter:2}sameElement(\"1\"))", [])
      assert_docs("#{array_name} contains ({elementFilter:3}sameElement(\"1\"))", [])

      assert_docs("#{array_name} contains ({elementFilter:0}sameElement(\"9\"))", [3, 4])
      assert_docs("#{array_name} contains ({elementFilter:1}sameElement(\"9\"))", [4])
      assert_docs("#{array_name} contains ({elementFilter:2}sameElement(\"9\"))", [2, 4])
      assert_docs("#{array_name} contains ({elementFilter:3}sameElement(\"9\"))", [])
    end

    ["byte_array", "int_array", "long_array"].each do |array_name|
      assert_docs("#{array_name} contains ({elementFilter:[0,1,2,3]}sameElement(\"1\"))", [0])

      assert_docs("#{array_name} contains ({elementFilter:[0]}sameElement(\"9\"))", [3, 4])
      assert_docs("#{array_name} contains ({elementFilter:[0,1]}sameElement(\"9\"))", [3, 4])
      assert_docs("#{array_name} contains ({elementFilter:[0,1,2]}sameElement(\"9\"))", [2, 3, 4])
      assert_docs("#{array_name} contains ({elementFilter:[0,1,2,3]}sameElement(\"9\"))", [2, 3, 4])
      assert_docs("#{array_name} contains ({elementFilter:[1,2,3]}sameElement(\"9\"))", [2, 4])
      assert_docs("#{array_name} contains ({elementFilter:[2,3]}sameElement(\"9\"))", [2, 4])
      assert_docs("#{array_name} contains ({elementFilter:[3]}sameElement(\"9\"))", [])

      # Test wrong order and duplicated elements
      assert_docs("#{array_name} contains ({elementFilter:[25,42,50000,0,0,0,0]}sameElement(\"9\"))", [3, 4])
      assert_docs("#{array_name} contains ({elementFilter:[3,2,3,2,1,0]}sameElement(\"9\"))", [2, 3, 4])
    end

    # Does not work yet, string gets tokenized
    #["float_array", "double_array"].each do |array_name|
    #  assert_docs("#{array_name} contains ({elementFilter:0}sameElement(\"1.0\"))", [0])
    #  assert_docs("#{array_name} contains ({elementFilter:1}sameElement(\"1.0\"))", [])
    #  assert_docs("#{array_name} contains ({elementFilter:2}sameElement(\"1.0\"))", [])
    #  assert_docs("#{array_name} contains ({elementFilter:3}sameElement(\"1.0\"))", [])
    #end

  end
end
