# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class LexicalRangeSearch < IndexedStreamingSearchTest

  def self.final_test_methods
    ['test_hit_limit']
  end

  DEBUG = false

  CLOSED = {}
  LEFT_OPEN = {"bounds" => "leftOpen"}
  RIGHT_OPEN = {"bounds" => "rightOpen"}
  OPEN = {"bounds" => "open"}

  CASED_FIELDS = %w[string_single_cased string_single_fast_cased string_multi_cased string_multi_fast_cased]
  UNCASED_FIELDS = %w[string_single string_single_fast string_multi string_multi_fast]
  FIELDS = CASED_FIELDS + UNCASED_FIELDS

  SINGLE_VALUE_FIELDS = %w[string_single_cased string_single_fast_cased string_single string_single_fast]
  MULTI_VALUE_FIELDS = %w[string_multi_cased string_multi_fast_cased string_multi string_multi_fast]

  def setup
    set_owner("boeker")
    set_description("Test lexi(cographi)cal range search")
  end


  ######################################################################################################################
  # Test case verifying that string ranges work as expected when matching is uncased
  ######################################################################################################################

  def feed_words(words)
    puts "Creating documents from #{words}"
    puts "Sorted: #{words.sort}"
    id = 0
    words.each do |word|
      vespa.document_api_v1.put(Document.new("id:test:test::#{id}")
                                        .add_field("id", id)
                                        .add_field("string_single", word)
                                        .add_field("string_single_fast", word)
                                        .add_field("string_multi", [word])
                                        .add_field("string_multi_fast", [word])
                                        .add_field("string_single_cased", word)
                                        .add_field("string_single_fast_cased", word)
                                        .add_field("string_multi_cased", [word])
                                        .add_field("string_multi_fast_cased", [word])
      )
      id += 1
    end
    wait_for_hitcount('query=sddocname:test', words.size)
  end

  def test_uncased_string_range
    deploy_app(SearchApp.new.cluster_name("test").sd(selfdir+"test.sd"))
    start

    # Fun fact: The capital ẞ was added to Unicode in 2008 and become part of German orthography only in 2017
    words = ["GAENSEFUESSCHEN", # 0
             "Gaensefuesschen", # 1
             "GÄNSEFÜSSCHEN",   # 2
             "GÄNSEFÜẞCHEN",    # 3
             "Gänsefüßchen",    # 4
             "SPAESSCHEN",      # 5
             "SPÄSSCHEN",       # 6
             "SPÄẞCHEN",        # 7
             "Spaesschen",      # 8
             "Späßchen"         # 9
    ]
    feed_words(words)

    # Verify cased matching: The order will be exactly as in the list above
    puts "Cased tests"
    CASED_FIELDS.each do |field_name|
      verify_words_cased(words, field_name)
    end

    # Uncased matching: Things collapse, verify sample queries
    # Equivalence classes:
    # gaensefuesschen (0, 1)
    # gänsefüsschen (2)
    # gänsefüßchen (3, 4)
    # spaesschen (5, 8)
    # spässchen (6)
    # späßchen (7, 9)
    puts "Uncased tests"

    UNCASED_FIELDS.each do |field_name|
      # 1 to 3
      # Closed: 0 and 4 will also match
      search_and_verify([0, 1, 2, 3, 4], CLOSED, field_name, words[1], words[3])
      # Left-open: 0 and 1 will not match anymore
      search_and_verify([2, 3, 4], LEFT_OPEN, field_name, words[1], words[3])
      # Right-open: 3 and 4 will not match anymore
      search_and_verify([0, 1, 2], RIGHT_OPEN, field_name, words[1], words[3])
      # Open: Only 2 will match
      search_and_verify([2], OPEN, field_name, words[1], words[3])

      # 6 to 7
      # Closed: 9 will also match (but not 8)
      search_and_verify([6, 7, 9], CLOSED, field_name, words[6], words[7])
      # Left-open: 6 will not match anymore
      search_and_verify([7, 9], LEFT_OPEN, field_name, words[6], words[7])
      # Right-open: 7 and 9 will not match anymore
      search_and_verify([6], RIGHT_OPEN, field_name, words[6], words[7])
      # Open: Nothing will match anymore
      search_and_verify([], OPEN, field_name, words[6], words[7])

      # 1 to 8
      # Closed: 0 will also match, but not 6, 7, 9
      search_and_verify([0, 1, 2, 3, 4, 5, 8], CLOSED, field_name, words[1], words[8])
      # Left-open: 0 and 1 will not match anymore
      search_and_verify([2, 3, 4, 5, 8], LEFT_OPEN, field_name, words[1], words[8])
      # Right-open: 5 and 8 will not match anymore
      search_and_verify([0, 1, 2, 3, 4], RIGHT_OPEN, field_name, words[1], words[8])
      # Open: 0, 1, 5, 8 will not match anymore
      search_and_verify([2, 3, 4], OPEN, field_name, words[1], words[8])

      # 0 to 9
      # Open: 0, 1, 7, and 9 will not match
      search_and_verify([2, 3, 4, 5, 6, 8], OPEN, field_name, words[0], words[9])
    end
  end

  def verify_words_cased(words, field_name)
    (0..words.length-1).each do |from|
      (0..words.length-1).each do |to|
        search_and_verify(from..to, CLOSED, field_name, words[from], words[to])
        search_and_verify((from+1)..to, LEFT_OPEN, field_name, words[from], words[to])
        search_and_verify(from..(to-1), RIGHT_OPEN, field_name, words[from], words[to])
        search_and_verify((from+1)..(to-1), OPEN, field_name, words[from], words[to])
      end
    end
  end

  def search_and_verify2(ids_prefix, ids_suffix, min_hits, max_hits, annotation, field_name, from, to)
    yql_query = get_yql_query(annotation, field_name, from, to)
    puts "YQL query: #{yql_query}" if DEBUG
    yql_result = search(yql_query)
    puts "YQL result: #{yql_result}" if DEBUG
    verify_ids(ids_prefix, ids_suffix, min_hits, max_hits, yql_result)

    select_query = get_select_query(annotation, field_name, from, to)
    puts "Select query: #{select_query}" if DEBUG
    select_result = vespa.container.values.first.post_search("/search/", select_query, 0, {'Content-Type' => 'application/json'})
    puts "Select result: #{select_result}" if DEBUG
    verify_ids(ids_prefix, ids_suffix, min_hits, max_hits, select_result)
  end

  def search_and_verify(expected_ids, annotation, field_name, from, to)
    expected_ids_array = Array(expected_ids)
    search_and_verify2(expected_ids_array, expected_ids_array, expected_ids_array.length, expected_ids_array.length, annotation, field_name, from, to)
  end

  def verify_ids(ids_prefix, ids_suffix, min_hits, max_hits, result)
    expected_ids_prefix_array = Array(ids_prefix)
    expected_ids_suffix_array = Array(ids_suffix)
    got_ids_array = result.hit.map{ |hit| hit.field["id"] }
    assert_true(min_hits <= got_ids_array.length, "Expected at least #{min_hits} hits, got #{got_ids_array.length}: #{got_ids_array}")
    assert_true(got_ids_array.length <= max_hits, "Expected at most #{max_hits} hits, got #{got_ids_array.length}: #{got_ids_array}")
    assert_true(expected_ids_prefix_array.length <= got_ids_array.length, "Expected prefix #{expected_ids_prefix_array} is longer than received hits #{got_ids_array}")
    assert_true(expected_ids_suffix_array.length <= got_ids_array.length, "Expected suffix #{expected_ids_suffix_array} is longer than received hits #{got_ids_array}")
    assert_equal(expected_ids_prefix_array, got_ids_array[0, expected_ids_prefix_array.length], "Expected prefix #{expected_ids_prefix_array}, but got #{got_ids_array}")
    assert_equal(expected_ids_suffix_array, got_ids_array[-expected_ids_suffix_array.length, expected_ids_suffix_array.length], "Expected suffix #{expected_ids_suffix_array}, but got #{got_ids_array}")
  end

  def get_yql_query(annotations, field_name, from, to)
    annotation_string = "{"
    first = true
    annotations.each do |k, v|
      annotation_string += ", " unless first
      first = false
      if v.is_a? String
        annotation_string += "#{k}:\"#{v}\""
      else
        annotation_string += "#{k}:#{v}"
      end
    end
    annotation_string += "}"

    from_str = from.nil? ? "-Infinity" : "\"#{from}\""
    to_str = to.nil? ? "Infinity" : "\"#{to}\""
    {"yql" => "select * from sources * where (#{annotation_string}range(#{field_name}, #{from_str}, #{to_str})) order by id asc", "hits" => 100}
  end

  def get_select_query(annotations, field_name, from, to)
    left_open = annotations.key?("bounds") && (annotations["bounds"].eql?("leftOpen") || annotations["bounds"].eql?("open"))
    right_open = annotations.key?("bounds") && (annotations["bounds"].eql?("rightOpen") || annotations["bounds"].eql?("open"))
    lower_bound = from.nil? ? {} : { (left_open ? ">" : ">=") => from }
    upper_bound = to.nil? ? {} : { (right_open ? "<" : "<=") => to }

    json = { "select" => { "where" => { "range" => { "children" => [ field_name, lower_bound.merge(upper_bound) ], "attributes" => annotations.except("bounds") } }},
             "sorting" => "id",
             "hits" => 100,
             "timeout" => 5 }
    json["streaming.selection"] = "true" if is_streaming

    json.to_json
  end

  ######################################################################################################################
  # Test case using hexadecimal representations of numbers as strings
  ######################################################################################################################

  def to_hex(n)
    "%08X" % n
  end

  def feed_hex_docs(range)
    range.each do |n|
      hex_string = to_hex(n) # Single hex string for single-value fields

      hex_strings = []
      hex_strings << to_hex(n) # Searching without prefix should work
      hex_strings << "foo" + to_hex(n) # Searching with prefix "foo" should work
      # Add some more junk values to the array: these should not influence the search
      (0..20).each do |i|
        hex_strings << "junk" + to_hex(i)
      end
      hex_strings << "bar" + to_hex(2 * n) # Searching with prefix "bar" for twice the number should also work


      vespa.document_api_v1.put(Document.new("id:test:test::#{n}")
                                        .add_field("id", n)
                                        .add_field("string_single", hex_string)
                                        .add_field("string_single_fast", hex_string)
                                        .add_field("string_multi", hex_strings)
                                        .add_field("string_multi_fast", hex_strings)
                                        .add_field("string_single_cased", hex_string)
                                        .add_field("string_single_fast_cased", hex_string)
                                        .add_field("string_multi_cased", hex_strings)
                                        .add_field("string_multi_fast_cased", hex_strings)
      )
    end
    wait_for_hitcount('query=sddocname:test', range.size)
  end

  def test_hex_string_range
    deploy_app(SearchApp.new.cluster_name("test").sd(selfdir+"test.sd"))
    start

    range = (8..18)
    feed_hex_docs(range)

    SINGLE_VALUE_FIELDS.each do |field_name|
      verify_bounded_hex_range(range, field_name)
      verify_unbounded_hex_range(range, field_name)
    end

    MULTI_VALUE_FIELDS.each do |field_name|
      verify_bounded_hex_range(range, field_name, "foo") # Hexadecimal strings prefixed with "foo"
      verify_bounded_hex_range(range, field_name, "bar", 2) # Hexadecimal strings prefixed with "bar", numbers multiplied with 2

      # Using Infinity on the left or right with "foo" or "bar" also selects all the values without a prefix or with the "junk" prefix => Matches everything
      puts "Testing field '#{field_name}' with hex numbers from #{range.first} to #{range.last}: Unbounded ranges"
      range.each do |mid|
        search_and_verify_hex(range.first..range.last, CLOSED, field_name, nil, mid, "foo")
        search_and_verify_hex(range.first..range.last, CLOSED, field_name, nil, mid, "bar", 2)
        search_and_verify_hex(range.first..range.last, CLOSED, field_name, mid, nil, "foo", 1)
        search_and_verify_hex(range.first..range.last, CLOSED, field_name, mid, nil, "bar", 2)
      end

    end
  end

  def verify_unbounded_hex_range(range, field_name)
    puts "Testing field '#{field_name}' with hex numbers from #{range.first} to #{range.last}: Unbounded ranges"

    # Unbounded on both sides
    search_and_verify_hex(range.first..range.last, CLOSED, field_name, nil, nil)

    # Unbounded on one side
    range.each do |mid|
      search_and_verify_hex(range.first..mid, CLOSED, field_name, nil, mid)
      search_and_verify_hex(mid..range.last, CLOSED, field_name, mid, nil)
    end
  end

  def verify_bounded_hex_range(range, field_name, prefix = "", factor = 1)
    puts "Testing field '#{field_name}' with hex numbers from #{range.first} to #{range.last}: Bounded ranges"

    range.each do |from|
      range.each do |to|
        search_and_verify_hex(from..to, CLOSED, field_name, from, to, prefix, factor)
        search_and_verify_hex((from+1)..to, LEFT_OPEN, field_name, from, to, prefix, factor)
        search_and_verify_hex(from..(to-1), RIGHT_OPEN, field_name, from, to, prefix, factor)
        search_and_verify_hex((from+1)..(to-1), OPEN, field_name, from, to, prefix, factor)
      end
    end
  end

  def search_and_verify_hex2(ids_prefix, ids_suffix, min_hits, max_hits, annotation, field_name, from, to, prefix = "", factor = 1)
    hex_from = from.nil? ? nil : "#{prefix}#{to_hex(factor * from)}"
    hex_to = to.nil? ? nil : "#{prefix}#{to_hex(factor * to)}"
    search_and_verify2(ids_prefix, ids_suffix, min_hits, max_hits, annotation, field_name, hex_from, hex_to)
  end

  def search_and_verify_hex_prefix(ids_prefix, annotation, field_name, from, to, prefix = "", factor = 1)
    # Allow two more hits than contained in the prefix
    ids_prefix_array = Array(ids_prefix)
    search_and_verify_hex2(ids_prefix_array, [], ids_prefix_array.length, ids_prefix_array.length + 2, annotation, field_name, from, to, prefix, factor)
  end

  def search_and_verify_hex_suffix(ids_suffix, annotation, field_name, from, to, prefix = "", factor = 1)
    # Allow two more hits than contained in the suffix
    ids_suffix_array = Array(ids_suffix)
    search_and_verify_hex2([], ids_suffix_array, ids_suffix_array.length, ids_suffix_array.length + 2, annotation, field_name, from, to, prefix, factor)
  end

  def search_and_verify_hex(expected_ids, annotation, field_name, from, to, prefix = "", factor = 1)
    expected_ids_array = Array(expected_ids)
    search_and_verify_hex2(expected_ids_array, expected_ids_array, expected_ids_array.length, expected_ids_array.length, annotation, field_name, from, to, prefix, factor)
  end

  def test_hit_limit
    @params = { :search_type => "INDEXED" }
    set_description("Verify that the hitLimit annotation works")
    deploy_app(SearchApp.new.cluster_name("test").sd(selfdir+"test.sd"))
    start

    range = (10..20)
    feed_hex_docs(range)

    # The hitLimit annotation requires an attribute with fast search enabled
    ["string_single_fast_cased", "string_single_fast", "string_multi_fast_cased", "string_multi_fast"].each do |field_name|
      prefix = field_name.include?("multi") ? "foo" : :""

      from = 12
      to = 18
      [0, 1, 2, 3].each do |i|
        # ascending
        search_and_verify_hex(from..from+i, CLOSED.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)
        search_and_verify_hex_prefix(from..from+i, RIGHT_OPEN.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)
        search_and_verify_hex_prefix(from+1..from+1+i, LEFT_OPEN.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)
        search_and_verify_hex_prefix(from+1..from+1+i, OPEN.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)

        # descending
        search_and_verify_hex(to-i..to, CLOSED.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
        search_and_verify_hex_suffix(to-i..to, LEFT_OPEN.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
        search_and_verify_hex_suffix(to-1-i..to-1, RIGHT_OPEN.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
        search_and_verify_hex_suffix(to-1-i..to-1, OPEN.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
      end

      # Check that we still can get the whole range
      search_and_verify_hex(from..to, CLOSED.merge({"hitLimit" => to - from + 1}), field_name, from, to, prefix)
      # hitLimit larger than range
      search_and_verify_hex(from..to, CLOSED.merge({"hitLimit" => to - from + 10}), field_name, from, to, prefix)

      # Now with a range that is larger than the range of documents
      from = 0
      to = 100
      [0, 1, 2, 3].each do |i|
        # ascending
        search_and_verify_hex(range.begin..range.begin+i, CLOSED.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)
        search_and_verify_hex_prefix(range.begin..range.begin+i, RIGHT_OPEN.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)
        search_and_verify_hex_prefix(range.begin..range.begin+i, LEFT_OPEN.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)
        search_and_verify_hex_prefix(range.begin..range.begin+i, OPEN.merge({"hitLimit" => i + 1}), field_name, from, to, prefix)

        # descending
        search_and_verify_hex(range.end-i..range.end, CLOSED.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
        search_and_verify_hex_suffix(range.end-i..range.end, LEFT_OPEN.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
        search_and_verify_hex_suffix(range.end-i..range.end, RIGHT_OPEN.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
        search_and_verify_hex_suffix(range.end-i..range.end, OPEN.merge({"hitLimit" => i + 1, "descending" => true}), field_name, from, to, prefix)
      end
    end

    # Unbounded ranges
    ["string_single_fast_cased", "string_single_fast"].each do |field_name|
      from = 12
      to = 18
      [CLOSED, LEFT_OPEN, RIGHT_OPEN, OPEN].each do |bounds|
        search_and_verify_hex_prefix([10], bounds.merge({"hitLimit" => 1}), field_name, nil, to)
        search_and_verify_hex_prefix([10, 11], bounds.merge({"hitLimit" => 2}), field_name, nil, to)
        search_and_verify_hex_prefix([10, 11, 12], bounds.merge({"hitLimit" => 3}), field_name, nil, to)

        search_and_verify_hex_suffix([20], bounds.merge({"hitLimit" => 1, "descending" => true}), field_name, from, nil)
        search_and_verify_hex_suffix([19, 20], bounds.merge({"hitLimit" => 2, "descending" => true}), field_name, from, nil)
        search_and_verify_hex_suffix([18, 19, 20], bounds.merge({"hitLimit" => 3, "descending" => true}), field_name, from, nil)
      end

      search_and_verify_hex(10..18, CLOSED.merge({"hitLimit" => 100}), field_name, nil, to)
      search_and_verify_hex(10..17, OPEN.merge({"hitLimit" => 100}), field_name, nil, to)
      search_and_verify_hex(10..20, CLOSED.merge({"hitLimit" => 100}), field_name, nil, nil)
      search_and_verify_hex(10..20, OPEN.merge({"hitLimit" => 100}), field_name, nil, nil)
    end

    ["string_multi_fast_cased", "string_multi_fast"].each do |field_name|
      from = 12
      to = 18
      [CLOSED, LEFT_OPEN, RIGHT_OPEN, OPEN].each do |bounds|
        search_and_verify_hex_prefix([10], bounds.merge({"hitLimit" => 1}), field_name, nil, to, "foo")
        search_and_verify_hex_prefix([10, 11], bounds.merge({"hitLimit" => 2}), field_name, nil, to, "foo")
        search_and_verify_hex_prefix([10, 11, 12], bounds.merge({"hitLimit" => 3}), field_name, nil, to, "foo")

        # The junk fields make hitLimit behave poorly: We get all documents, even with a hitLimit
        search_and_verify_hex2([], [20], 1, 11, bounds.merge({"hitLimit" => 1, "descending" => true}), field_name, from, nil, "foo")
        search_and_verify_hex2([], [19, 20], 2, 11, bounds.merge({"hitLimit" => 2, "descending" => true}), field_name, from, nil, "foo")
        search_and_verify_hex2([], [18, 19, 20], 3, 11, bounds.merge({"hitLimit" => 3, "descending" => true}), field_name, from, nil, "foo")
      end

      # We get all document every time
      search_and_verify_hex(10..20, CLOSED.merge({"hitLimit" => 100}), field_name, nil, to, "foo")
      search_and_verify_hex(10..20, OPEN.merge({"hitLimit" => 100}), field_name, nil, to, "foo")
      search_and_verify_hex(10..20, CLOSED.merge({"hitLimit" => 100}), field_name, nil, nil, "foo")
      search_and_verify_hex(10..20, OPEN.merge({"hitLimit" => 100}), field_name, nil, nil, "foo")
    end
  end

  ######################################################################################################################
  # Test case for verifying that ranking works (using hexadecimal representations of numbers as strings)
  ######################################################################################################################

  def test_ranking
    deploy_app(SearchApp.new.cluster_name("test").sd(selfdir+"test.sd"))
    start

    range = [1, 2]
    feed_hex_docs(range)

    FIELDS.each do |field_name|
      puts "Checking ranking for field '#{field_name}'"

      # Range matches document 2, but query matches document 1 and 2
      query = {"yql" => "select * from sources * where true or range(#{field_name}, \"#{to_hex(2)}\", \"#{to_hex(2)}\") order by id asc",
               "ranking" => "my-rank-profile"}
      puts "Query: #{query}"
      result = search(query)
      #puts result
      assert_equal(2, result.hit.size)

      # Verify that range matching document 2 (and not document 1) is correctly reported
      puts "Hit 0 matchfeatures: #{result.hit[0].field["matchfeatures"]}"
      FIELDS.each do |match_field_name|
        puts "Verifying that field '#{match_field_name}' does not match"
        assert_equal(0.0, result.hit[0].field["matchfeatures"]["matches(#{match_field_name})"])
      end

      puts "Hit 1 matchfeatures: #{result.hit[1].field["matchfeatures"]}"
      # Match reported for field_name
      puts "Verifying that field '#{field_name}' does match"
      assert_equal(1.0, result.hit[1].field["matchfeatures"]["matches(#{field_name})"])
      # No match reported for the other fields
      (FIELDS - [field_name]).each do |match_field_name|
        puts "Verifying that field '#{match_field_name}' does not match"
        assert_equal(0.0, result.hit[1].field["matchfeatures"]["matches(#{match_field_name})"])
      end
    end
  end
end
