# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class LexicalRangeSearch < IndexedStreamingSearchTest

  DEBUG = false

  CLOSED = ""
  LEFT_OPEN = "{bounds:\"leftOpen\"}"
  RIGHT_OPEN = "{bounds:\"rightOpen\"}"
  OPEN = "{bounds:\"open\"}"

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

  def search_and_verify(expected_ids, annotation, field_name, from, to)
    yql_query = get_yql_query(annotation, field_name, from, to)
    puts "YQL query: #{yql_query}" if DEBUG
    yql_result = search(yql_query)
    puts "YQL result: #{yql_result}" if DEBUG
    verify_ids(expected_ids, yql_result)

    select_query = get_select_query(annotation, field_name, from, to)
    puts "Select query: #{select_query}" if DEBUG
    select_result = vespa.container.values.first.post_search("/search/", select_query, 0, {'Content-Type' => 'application/json'})
    puts "Select result: #{select_result}" if DEBUG
    verify_ids(expected_ids, select_result)
  end

  def verify_ids(expected_ids, result)
    expected_ids_array = Array(expected_ids)
    got_ids_array = result.hit.map{ |hit| hit.field["id"] }
    assert_equal(expected_ids_array, got_ids_array)
  end

  def get_yql_query(annotation, field_name, from, to)
    from_str = from.nil? ? "-Infinity" : "\"#{from}\""
    to_str = to.nil? ? "Infinity" : "\"#{to}\""
    {"yql" => "select * from sources * where (#{annotation}range(#{field_name}, #{from_str}, #{to_str})) order by id asc", "hits" => 100}
  end

  def get_select_query(annotation, field_name, from, to)
    lower_bound = from.nil? ? {} : { ((annotation.eql? LEFT_OPEN) || (annotation.eql? OPEN) ? ">" : ">=") => from }
    upper_bound = to.nil? ? {} : { ((annotation.eql? RIGHT_OPEN) || (annotation.eql? OPEN) ? "<" : "<=") => to }

    json = { "select" => { "where" => { "range" => [ field_name, lower_bound.merge(upper_bound) ] } },
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
        search_and_verify_hex(range.first..range.last, "", field_name, nil, mid, "foo")
        search_and_verify_hex(range.first..range.last, "", field_name, nil, mid, "bar", 2)
        search_and_verify_hex(range.first..range.last, "", field_name, mid, nil, "foo", 1)
        search_and_verify_hex(range.first..range.last, "", field_name, mid, nil, "bar", 2)
      end

    end
  end

  def verify_unbounded_hex_range(range, field_name)
    puts "Testing field '#{field_name}' with hex numbers from #{range.first} to #{range.last}: Unbounded ranges"

    range.each do |mid|
      search_and_verify_hex(range.first..mid, "", field_name, nil, mid)
      search_and_verify_hex(mid..range.last, "", field_name, mid, nil)
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

  def search_and_verify_hex(expected_ids, annotation, field_name, from, to, prefix = "", factor = 1)
    hex_from = from.nil? ? nil : "#{prefix}#{to_hex(factor * from)}"
    hex_to = to.nil? ? nil : "#{prefix}#{to_hex(factor * to)}"
    search_and_verify(expected_ids, annotation, field_name, hex_from, hex_to)
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
