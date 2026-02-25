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

  # Returns all query variants that should produce the same result for a given
  # array field, element filter indices, and match value.
  def build_queries(array_name, indices, value)
    queries = []
    if indices.empty?
      queries << "#{array_name} contains sameElement(\"#{value}\")"
      queries << "#{array_name} contains ({elementFilter:[]}sameElement(\"#{value}\"))"
    else
      queries << "#{array_name} contains ({elementFilter:[#{indices.join(',')}]}sameElement(\"#{value}\"))"
      if indices.length == 1
        queries << "#{array_name} contains ({elementFilter:#{indices[0]}}sameElement(\"#{value}\"))"

        # syntax sugar: field[index] = value
        queries << "#{array_name}[#{indices[0]}]=#{add_quotes_if_string(value)}"
      end
    end
    queries
  end

  def add_quotes_if_string(s)
    return s if ["true", "false"].include?(s)
    return s if is_number(s)
    "\"#{s}\""
  end

  def is_number(s)
    s.match?(/\A-?\d+(\.\d+)?\z/)
  end

  def assert_element_filter(array_name, indices, expected_docids, value)
    build_queries(array_name, indices, value).each do |query|
      assert_docs(query, expected_docids)
    end
  end


  def test_bool_array
    set_description('Use elementFilter annotation of sameElement operator for indexing array of bools.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    feed_docs({"bool_array" => [[true, true, false], [false, false, true], [true, false, false], [false, true, false], [false, false, false]]})

    # [array, indices, expected_docids, value]
    [
      ["bool_array", [0],              [0, 2],           "true"],
      ["bool_array", [1],              [0, 3],           "true"],
      ["bool_array", [2],              [1],              "true"],
      ["bool_array", [3],              [],               "true"],
      ["bool_array", [0, 1],           [0, 2, 3],        "true"],
      ["bool_array", [0, 1, 2],        [0, 1, 2, 3],     "true"],
      ["bool_array", [0, 1, 2, 3],     [0, 1, 2, 3],     "true"],
      ["bool_array", [1, 2, 3],        [0, 1, 3],        "true"],
      ["bool_array", [2, 3],           [1],              "true"],
      ["bool_array", [0],              [1, 3, 4],        "false"],
      ["bool_array", [1],              [1, 2, 4],        "false"],
      ["bool_array", [2],              [0, 2, 3, 4],     "false"],
      ["bool_array", [3],              [],               "false"],
      ["bool_array", [0, 1, 2, 3],     [0, 1, 2, 3, 4],  "false"],
      # Wrong order and duplicated elements
      ["bool_array", [0, 0, 0, 0],     [0, 2],           "true"],
      ["bool_array", [25, 25, 25, 0],  [0, 2],           "true"],
    ].each do |array_name, indices, expected_docids, value|
      assert_element_filter(array_name, indices, expected_docids, value)
    end
  end


  def test_string_array
    set_description('Use elementFilter annotation of sameElement operator for indexing array of strings.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    feed_docs({"string_array" => [["foo", "bar", "baz"], ["foo", "bar", "bar"], ["foo", "foo", "foo"], ["bar", "bar", "foo"], ["baz", "baz", "baz"]]})

    # [array, indices, expected_docids, value]
    [
      ["string_array", [],              [0, 4],  "baz"],
      ["string_array", [0],             [4],     "baz"],
      ["string_array", [1],             [4],     "baz"],
      ["string_array", [2],             [0, 4],  "baz"],
      ["string_array", [3],             [],      "baz"],
      ["string_array", [0, 1],          [4],     "baz"],
      ["string_array", [0, 1, 2],       [0, 4],  "baz"],
      ["string_array", [0, 1, 2, 3],    [0, 4],  "baz"],
      ["string_array", [1, 2, 3],       [0, 4],  "baz"],
      ["string_array", [2, 3],          [0, 4],  "baz"],
      # Wrong order and duplicated elements
      ["string_array", [0, 0, 0, 0],    [4],     "baz"],
      ["string_array", [25, 25, 25, 0], [4],     "baz"],
    ].each do |array_name, indices, expected_docids, value|
      assert_element_filter(array_name, indices, expected_docids, value)
    end
  end


  def test_numerical_arrays
    set_description('Use elementFilter annotation of sameElement operator for indexing arrays of numbers.')
    deploy_app(SearchApp.new.sd(selfdir+'arrays.sd'))
    start

    int_arrays = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [9, 5, 4], [9, 9, 9]]
    float_arrays = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0], [9.0, 5.0, 4.0], [9.0, 9.0, 9.0]]

    feed_docs({"byte_array" => int_arrays, "int_array" => int_arrays, "long_array" => int_arrays, "float_array" => float_arrays, "double_array" => float_arrays})

    # [indices, expected_docids, value]
    test_data = [
      [[],                             [2, 3, 4], "9"],
      [[0],                            [0],       "1"],
      [[1],                            [],        "1"],
      [[2],                            [],        "1"],
      [[3],                            [],        "1"],
      [[0, 1, 2, 3],                   [0],       "1"],
      [[0],                            [3, 4],    "9"],
      [[1],                            [4],       "9"],
      [[2],                            [2, 4],    "9"],
      [[3],                            [],        "9"],
      [[0, 1],                         [3, 4],    "9"],
      [[0, 1, 2],                      [2, 3, 4], "9"],
      [[0, 1, 2, 3],                   [2, 3, 4], "9"],
      [[1, 2, 3],                      [2, 4],    "9"],
      [[2, 3],                         [2, 4],    "9"],
      # Wrong order and duplicated elements
      [[25, 42, 50000, 0, 0, 0, 0],    [3, 4],    "9"],
      [[3, 2, 3, 2, 1, 0],             [2, 3, 4], "9"],
    ]

    ["byte_array", "int_array", "long_array"].each do |array_name|
      test_data.each do |indices, expected_docids, value|
        assert_element_filter(array_name, indices, expected_docids, value)
      end
    end

    # Does not work yet, string gets tokenized
    #["float_array", "double_array"].each do |array_name|
    #  assert_element_filter(array_name, [0], [0], "1.0")
    #  assert_element_filter(array_name, [1], [],  "1.0")
    #  assert_element_filter(array_name, [2], [],  "1.0")
    #  assert_element_filter(array_name, [3], [],  "1.0")
    #end

  end
end
