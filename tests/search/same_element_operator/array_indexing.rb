# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

require 'json'

class ElementFilterAnnotation < IndexedStreamingSearchTest

  def setup
    set_owner('boeker')
  end

  def test_element_filter_annotation
    set_description('Use elementFilter annotation of sameElement operator for array indexing.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    feed_docs

    # Use the elementFilter annotation of the sameElement operator to limit it to specific ids,
    # effectively indexing the array at the specified positions.
    assert_docs("string_array contains ({elementFilter:0}sameElement(\"baz\"))", [4])
    assert_docs("string_array contains ({elementFilter:1}sameElement(\"baz\"))", [4])
    assert_docs("string_array contains ({elementFilter:2}sameElement(\"baz\"))", [0, 4])
    assert_docs("string_array contains ({elementFilter:3}sameElement(\"baz\"))", [])

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

    # Does not work, string gets tokenized
    #["float_array", "double_array"].each do |array_name|
    #  assert_docs("#{array_name} contains ({elementFilter:0}sameElement(\"1.0\"))", [0])
    #  assert_docs("#{array_name} contains ({elementFilter:1}sameElement(\"1.0\"))", [])
    #  assert_docs("#{array_name} contains ({elementFilter:2}sameElement(\"1.0\"))", [])
    #  assert_docs("#{array_name} contains ({elementFilter:3}sameElement(\"1.0\"))", [])
    #end
  end


  def test_element_filter_annotation_when_empty
    set_description('Use elementFilter annotation of sameElement operator for array indexing using multiple indices.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    feed_docs

    # An empty list means "no filtering" and behaves as if no annotation is present.
    assert_docs("string_array contains sameElement(\"baz\")", [0, 4])
    assert_docs("string_array contains ({elementFilter:[]}sameElement(\"baz\"))", [0, 4])

    ["byte_array", "int_array", "long_array"].each do |array_name|
      assert_docs("#{array_name} contains sameElement(\"9\")", [2, 3, 4])
      assert_docs("#{array_name} contains ({elementFilter:[]}sameElement(\"9\"))", [2, 3, 4])
    end

  end


  def test_element_filter_annotation_with_multiple_ids
    set_description('Use elementFilter annotation of sameElement operator for array indexing using multiple indices.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    feed_docs

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

    end

  def feed_docs
    string_arrays = [
      ["foo", "bar", "baz"],
      ["foo", "bar", "bar"],
      ["foo", "foo", "foo"],
      ["bar", "bar", "foo"],
      ["baz", "baz", "baz"]
    ]

    int_arrays = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
      [9, 5, 4],
      [9, 9, 9]
    ]

    float_arrays = [
      [1.0, 2.0, 3.0],
      [4.0, 5.0, 6.0],
      [7.0, 8.0, 9.0],
      [9.0, 5.0, 4.0],
      [9.0, 9.0, 9.0]
    ]

    for i in 0...5 do
      vespa.document_api_v1.put(Document.new("id:arrays:arrays::#{i}")
                                        .add_field("id", i)
                                        .add_field("string_array", string_arrays[i])
                                        .add_field("byte_array", int_arrays[i])
                                        .add_field("int_array", int_arrays[i])
                                        .add_field("long_array", int_arrays[i])
                                        .add_field("float_array", float_arrays[i])
                                        .add_field("double_array", float_arrays[i])
      )
    end
    wait_for_hitcount("?query=sddocname:arrays", 5)
  end

  def assert_docs(match_condition, expected_docids)
    query = {'yql' => "select * from sources * where #{match_condition} order by id asc"}
    puts "query: #{query}"
    puts "expected_docids: #{expected_docids}"
    result = search(query)
    #puts "result: #{result.json}"
    assert_hitcount(result, expected_docids.length)
    for i in 0...expected_docids.length do
      assert_field_value(result, "documentid", "id:arrays:arrays::#{expected_docids[i]}", i)
    end
  end


end
