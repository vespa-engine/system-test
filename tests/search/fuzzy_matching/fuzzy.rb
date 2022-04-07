# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'cgi'

class FuzzySearch < IndexedSearchTest

  def setup
    set_owner("alexeyche")
    set_description("Testing fuzzy operator")
  end

  MAX_EDIT_DISTANCE_DEFAULT = 2
  PREFIX_LENGTH_DEFAULT = 0

  FIELDS = [
    "single_scan_uncased", 
    "array_slow", 
    "array_fast", 
    "wset_slow", 
    "wset_fast",
    "single_btree_uncased",
    # "single_btree_cased", # TODO
    # "single_hash_cased", 
    # "single_scan_cased", 
    # "single_index" 
  ]

  def make_term(field, word)
    my_term = "#{field} contains \"#{word}\""
  end

  def make_fuzzy(
    field, 
    word, 
    max_edit_distance: MAX_EDIT_DISTANCE_DEFAULT,
    prefix_length: PREFIX_LENGTH_DEFAULT
  )
    is_max_edit_distance_set = max_edit_distance != MAX_EDIT_DISTANCE_DEFAULT
    is_prefix_length_set = prefix_length != PREFIX_LENGTH_DEFAULT

    annotations = ""
    annotations += is_max_edit_distance_set || is_prefix_length_set ? "{" : ""
    annotations += is_max_edit_distance_set ? "maxEditDistance:#{max_edit_distance}" : ""
    annotations += is_max_edit_distance_set && is_prefix_length_set ? "," : ""
    annotations += is_prefix_length_set ? "prefixLength:#{prefix_length}" : ""
    annotations += is_max_edit_distance_set || is_prefix_length_set ? "}" : ""

    where_clause = "#{field} contains "
    where_clause += is_max_edit_distance_set || is_prefix_length_set ? "(" : ""
    where_clause += "#{annotations}fuzzy(\"#{word}\")"
    where_clause += is_max_edit_distance_set || is_prefix_length_set ? ")" : ""
    where_clause
  end

  def make_query(a)
    my_query = "query=" + CGI::escape("select * from sources * where #{a}") + "&type=yql"
    puts "QUERY: select * from sources * where #{a}"
    my_query
  end

  def test_fuzzysearch
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 6, :file => selfdir + "docs.xml")
    FIELDS.each { |f| 
      run_fuzzysearch_default_tests(f) 
      run_fuzzysearch_max_edit_tests(f)
    }
    run_fuzzysearch_prefix_length_tests("array_fast")
    run_fuzzysearch_prefix_length_tests("array_slow")
  end

  def run_fuzzysearch_default_tests(f)
    puts "Running fuzzy search tests with default parameters: #{f}"

    assert_hitcount(make_query(make_fuzzy(f, "ThisIsAFox")), 5)
    assert_hitcount(make_query(make_fuzzy(f, "ThisIsAFo1")), 4)
    assert_hitcount(make_query(make_fuzzy(f, "ThisIsA11")), 1)
    assert_hitcount(make_query(make_fuzzy(f, "ThisIs")), 1)
    assert_hitcount(make_query(make_fuzzy(f, "1hisIs")), 1)
    assert_hitcount(make_query(make_fuzzy(f, "1")), 0)
  end

  def run_fuzzysearch_max_edit_tests(f)
    puts "Running fuzzy search tests for maxEditDistance: #{f}"

    assert_hitcount(make_query(make_fuzzy(f, "a", max_edit_distance: 100)), 6)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox", max_edit_distance: 100)), 6)
    assert_hitcount(make_query(make_fuzzy(f, "1111111111", max_edit_distance: 100)), 6)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox", max_edit_distance: 0)), 2)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox", max_edit_distance: 1)), 4)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox1", max_edit_distance: 1)), 2)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox11", max_edit_distance: 1)), 0)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox1", max_edit_distance: 0)), 0)
  end

  def run_fuzzysearch_prefix_length_tests(f)
    puts "Running fuzzy search tests for prefixLength: #{f}"
    
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox", prefix_length: 10)), 2)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox", prefix_length: 100)), 2)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox", prefix_length: 100, max_edit_distance: 100)), 2)
    assert_hitcount(make_query(make_fuzzy(f, "Thisisafox", prefix_length: 6, max_edit_distance: 100)), 5)
    assert_hitcount(make_query(make_fuzzy(f, "T", prefix_length: 1, max_edit_distance: 100)), 5)
    assert_hitcount(make_query(make_fuzzy(f, "ThisIsA", prefix_length: 7, max_edit_distance: 100)), 4)
  end

  def teardown
    stop
  end
end
