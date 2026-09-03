# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class LexicalRangeSearch < IndexedStreamingSearchTest

  CLOSED = ""
  LEFT_OPEN = "{bounds:\"leftOpen\"}"
  RIGHT_OPEN = "{bounds:\"rightOpen\"}"
  OPEN = "{bounds:\"open\"}"

  CASED_FIELDS = %w[string_single_cased string_single_fast_cased string_multi_cased string_multi_fast_cased]
  UNCASED_FIELDS = %w[string_single string_single_fast string_multi string_multi_fast]

  def setup
    set_owner("boeker")
    set_description("Test lexi(cographi)cal range search")
  end


  ######################################################################################################################
  # Test case verifying that string ranges work as expected when matching is uncased
  ######################################################################################################################

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
      search_and_verify([0, 1, 2, 3, 4], get_query(CLOSED, field_name, words[1], words[3]))
      # Left-open: 0 and 1 will not match anymore
      search_and_verify([2, 3, 4], get_query(LEFT_OPEN, field_name, words[1], words[3]))
      # Right-open: 3 and 4 will not match anymore
      search_and_verify([0, 1, 2], get_query(RIGHT_OPEN, field_name, words[1], words[3]))
      # Open: Only 2 will match
      search_and_verify([2], get_query(OPEN, field_name, words[1], words[3]))

      # 6 to 7
      # Closed: 9 will also match (but not 8)
      search_and_verify([6, 7, 9], get_query(CLOSED, field_name, words[6], words[7]))
      # Left-open: 6 will not match anymore
      search_and_verify([7, 9], get_query(LEFT_OPEN, field_name, words[6], words[7]))
      # Right-open: 7 and 9 will not match anymore
      search_and_verify([6], get_query(RIGHT_OPEN, field_name, words[6], words[7]))
      # Open: Nothing will match anymore
      search_and_verify([], get_query(OPEN, field_name, words[6], words[7]))

      # 1 to 8
      # Closed: 0 will also match, but not 6, 7, 9
      search_and_verify([0, 1, 2, 3, 4, 5, 8], get_query(CLOSED, field_name, words[1], words[8]))
      # Left-open: 0 and 1 will not match anymore
      search_and_verify([2, 3, 4, 5, 8], get_query(LEFT_OPEN, field_name, words[1], words[8]))
      # Right-open: 5 and 8 will not match anymore
      search_and_verify([0, 1, 2, 3, 4], get_query(RIGHT_OPEN, field_name, words[1], words[8]))
      # Open: 0, 1, 5, 8 will not match anymore
      search_and_verify([2, 3, 4], get_query(OPEN, field_name, words[1], words[8]))

      # 0 to 9
      # Open: 0, 1, 7, and 9 will not match
      search_and_verify([2, 3, 4, 5, 6, 8], get_query(OPEN, field_name, words[0], words[9]))
    end
  end

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

  def verify_words_cased(words, field_name)
    (0..words.length-1).each do |from|
      (0..words.length-1).each do |to|
        search_and_verify(from..to, get_query(CLOSED, field_name, words[from], words[to]))
        search_and_verify((from+1)..to, get_query(LEFT_OPEN, field_name, words[from], words[to]))
        search_and_verify(from..(to-1), get_query(RIGHT_OPEN, field_name, words[from], words[to]))
        search_and_verify((from+1)..(to-1), get_query(OPEN, field_name, words[from], words[to]))
      end
    end
  end

  def search_and_verify(expected_ids, query)
    result = search(query)
    #puts "#{query["yql"]}"
    #puts result
    verify_ids(expected_ids, result)
  end

  def verify_ids(expected_ids, result)
    expected_ids_array = Array(expected_ids)
    got_ids_array = result.hit.map{ |hit| hit.field["id"] }
    assert_equal(expected_ids_array, got_ids_array)
  end

  def get_query(annotation, field_name, from, to)
    from_str = from.nil? ? "-Infinity" : "\"#{from}\""
    to_str = to.nil? ? "Infinity" : "\"#{to}\""
    {"yql" => "select * from sources * where (#{annotation}range(#{field_name}, #{from_str}, #{to_str})) order by id asc", "hits" => 100}
  end

  ######################################################################################################################
  # Test case using hexadecimal representations of numbers as strings
  ######################################################################################################################

  def test_hex_string_range
    deploy_app(SearchApp.new.cluster_name("test").sd(selfdir+"test.sd"))
    start

    range = (0..20)
    feed_hex_docs(range)

    # Cased and uncased fields should yield the same results
    CASED_FIELDS.each do |field_name|
      verify_hex_range(range, field_name)
    end
    UNCASED_FIELDS.each do |field_name|
      verify_hex_range(range, field_name)
    end
  end

  def to_hex(n)
    "%08X" % n
  end

  def feed_hex_docs(range)
    range.each do |n|
      hex_string = to_hex(n)
      hex_strings = [to_hex(n)]
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

  def verify_hex_range(range, field_name)
    puts "Testing field '#{field_name}' with hex numbers from #{range.first} to #{range.last}"

    # Unbounded ranges
    range.each do |mid|
      search_and_verify(range.first..mid, get_hex_query("", field_name, nil, mid))
      search_and_verify(mid..range.last, get_hex_query("", field_name, mid, nil))
    end

    # Bounded ranges
    range.each do |from|
      range.each do |to|
        search_and_verify(from..to, get_hex_query(CLOSED, field_name, from, to))
        search_and_verify((from+1)..to, get_hex_query(LEFT_OPEN, field_name, from, to))
        search_and_verify(from..(to-1), get_hex_query(RIGHT_OPEN, field_name, from, to))
        search_and_verify((from+1)..(to-1), get_hex_query(OPEN, field_name, from, to))
      end
    end
  end

  def get_hex_query(annotation, field_name, from, to)
    from_str = from.nil? ? "-Infinity" : "\"#{to_hex(from)}\""
    to_str = to.nil? ? "Infinity" : "\"#{to_hex(to)}\""
    {"yql" => "select * from sources * where (#{annotation}range(#{field_name}, #{from_str}, #{to_str})) order by id asc", "hits" => 100}
  end

end
