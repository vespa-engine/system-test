# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'
require 'cgi'

class FuzzySearch < IndexedStreamingSearchTest

  def setup
    set_owner("alexeyche")
    set_description("Testing fuzzy operator")
  end

  MAX_EDIT_DISTANCE_DEFAULT = 2
  
  PREFIX_LENGTH_DEFAULT = 0

  UNCASED_FIELDS = [
    "single_scan_uncased", 
    "array_slow", 
    "array_fast", 
    "wset_slow", 
    "wset_fast",
    "single_btree_uncased",
    "fs_single_btree_uncased"
  ]

  ARRAY_FIELDS = [
    "array_slow",
    "array_fast",
    "wset_slow",
    "wset_fast"
  ]
  
  CASED_FIELDS = [
    "single_btree_cased",
    "single_hash_cased", 
    "single_scan_cased"
  ]

  def make_term(field, word)
    my_term = "#{field} contains \"#{word}\""
  end

  def make_fuzzy(
    field, 
    word, 
    max_edit_distance,
    prefix_length,
    prefix_match
  )
    is_max_edit_distance_set = max_edit_distance != MAX_EDIT_DISTANCE_DEFAULT
    is_prefix_length_set = prefix_length != PREFIX_LENGTH_DEFAULT

    annotations = []
    annotations.append("maxEditDistance:#{max_edit_distance}") if is_max_edit_distance_set
    annotations.append("prefixLength:#{prefix_length}")        if is_prefix_length_set
    annotations.append("prefix:true")                          if prefix_match
    annotations_str = annotations.empty? ? '' : "{#{annotations.join(',')}}"

    where_clause = "#{field} contains "
    where_clause += annotations.empty? ? "" : "("
    where_clause += "#{annotations_str}fuzzy(\"#{word}\")"
    where_clause += annotations.empty? ? "" : ")"
    where_clause
  end

  def make_query(a)
    yql_query = CGI::escape("select * from sources * where #{a}")
    my_query = "query=" + yql_query + "&type=yql"
    my_query
  end

  def assert_documents(query, exp_docids)
    result = search(query)
    assert_hitcount(result, exp_docids.size)
    result.sort_results_by("documentid")
    for i in 0...exp_docids.size do
      exp_docid = "id:test:test::#{exp_docids[i]}"
      assert_field_value(result, "documentid", exp_docid, i)
    end
  end

  def assert_fuzzy(
    field, 
    query, 
    exp_docids,
    max_edit_distance: MAX_EDIT_DISTANCE_DEFAULT,
    prefix_length: PREFIX_LENGTH_DEFAULT,
    prefix_match: false
  )
    q = make_query(make_fuzzy(
      field, 
      query, 
      max_edit_distance, 
      prefix_length,
      prefix_match
    ))
    assert_documents(q, exp_docids)
  end

  def test_fuzzysearch
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 6, :file => selfdir + "docs.json")

    UNCASED_FIELDS.each { |f| 
      run_fuzzysearch_default_tests(f) 
      run_fuzzysearch_max_edit_tests(f)
      run_fuzzysearch_prefix_length_tests(f)
      run_fuzzy_search_prefix_match_tests(f)
      run_fuzzy_search_prefix_locking_and_prefix_match_tests(f)
    }

    ARRAY_FIELDS.each { |f|
      run_fuzzysearch_array_tests(f)
    }

    CASED_FIELDS.each { |f| 
      run_fuzzysearch_default_cased_tests(f)
    }

    # Indexing field is not supported
    assert_query_errors(
      make_query(make_fuzzy("single_index", "query", 2, 0, false)),
      [".*Fuzzy items require a string attribute field, but 'single_index' is not"]
    )
  end

  def run_fuzzysearch_array_tests(f)
    puts "Running fuzzy search tests for an array match: #{f}"

    assert_fuzzy(f, "Bear", [1, 2])
    assert_fuzzy(f, "Bear", [1, 2], prefix_length: 3)
    assert_fuzzy(f, "Bear", [1], prefix_length: 4)
    assert_fuzzy(f, "Beaver1", [2])
  end

  def run_fuzzysearch_default_tests(f)
    puts "Running fuzzy search tests with default parameters: #{f}"

    assert_fuzzy(f, "ThisIsAFox", [1, 2, 3, 4, 6])
    assert_fuzzy(f, "ThisIsAFo1", [1, 2, 3, 4])
    assert_fuzzy(f, "ThisIsA11", [4])
    assert_fuzzy(f, "ThisIs", [5])
    assert_fuzzy(f, "1hisIs", [5])
    assert_fuzzy(f, "1", [])
  end

  def run_fuzzysearch_max_edit_tests(f)
    puts "Running fuzzy search tests for maxEditDistance: #{f}"

    assert_fuzzy(f, "a", [1, 2, 3, 4, 5, 6], max_edit_distance: 100)
    assert_fuzzy(f, "Thisisafox", [1, 2, 3, 4, 5, 6], max_edit_distance: 100)
    assert_fuzzy(f, "1111111111", [1, 2, 3, 4, 5, 6], max_edit_distance: 100)
    assert_fuzzy(f, "Thisisafox", [1, 2], max_edit_distance: 0)
    assert_fuzzy(f, "Thisisafox", [1, 2, 3, 4], max_edit_distance: 1)
    assert_fuzzy(f, "Thisisafox1", [1, 2], max_edit_distance: 1)
    assert_fuzzy(f, "Thisisafox11", [], max_edit_distance: 1)
    assert_fuzzy(f, "Thisisafox1", [], max_edit_distance: 0)
  end

  def run_fuzzysearch_prefix_length_tests(f)
    puts "Running fuzzy search tests for prefixLength: #{f}"
    
    assert_fuzzy(f, "Thisisafox", [1, 2], prefix_length: 10)
    assert_fuzzy(f, "Thisisafox", [1, 2], prefix_length: 100)
    assert_fuzzy(f, "Thisisafox", [1, 2], prefix_length: 100, max_edit_distance: 100)
    assert_fuzzy(f, "Thisisafox", [1, 2, 3, 4, 5], prefix_length: 6, max_edit_distance: 100)
    assert_fuzzy(f, "T", [1, 2, 3, 4, 5], prefix_length: 1, max_edit_distance: 100)
    assert_fuzzy(f, "ThisIsA", [1, 2, 3, 4], prefix_length: 7, max_edit_distance: 100)
  end

  def run_fuzzy_search_prefix_match_tests(f)
    puts "Running fuzzy search for `prefix:true`: #{f}"

    assert_fuzzy(f, "This",       [1, 2, 3, 4, 5],    max_edit_distance: 0, prefix_match: true)
    assert_fuzzy(f, "Thus",       [1, 2, 3, 4, 5],    max_edit_distance: 1, prefix_match: true)
    assert_fuzzy(f, "his",        [1, 2, 3, 4, 5, 6], max_edit_distance: 1, prefix_match: true)
    assert_fuzzy(f, "is",         [6],                max_edit_distance: 1, prefix_match: true)
    assert_fuzzy(f, "is",         [1, 2, 3, 4, 5, 6], max_edit_distance: 2, prefix_match: true)
    assert_fuzzy(f, "thisisafox", [1, 2, 3, 4],       max_edit_distance: 1, prefix_match: true)
    assert_fuzzy(f, "thisisafox", [1, 2, 3, 4, 6],    max_edit_distance: 2, prefix_match: true)
    assert_fuzzy(f, "thXsisafox", [1, 2, 3, 4],       max_edit_distance: 2, prefix_match: true)
    assert_fuzzy(f, "thXsisafox", [1, 2, 3, 4, 6],    max_edit_distance: 3, prefix_match: true)
    assert_fuzzy(f, "thisisafox", [1, 2, 3, 4, 5, 6], max_edit_distance: 4, prefix_match: true)
  end

  def run_fuzzy_search_prefix_locking_and_prefix_match_tests(f)
    puts "Running fuzzy search for prefixLength combined with `prefix:true`: #{f}"

    assert_fuzzy(f, "thisisafox", [1, 2],          max_edit_distance: 1, prefix_length: 10, prefix_match: true)
    assert_fuzzy(f, "thus",       [1, 2, 3, 4, 5], max_edit_distance: 1, prefix_length: 2, prefix_match: true)
    assert_fuzzy(f, "that",       [],              max_edit_distance: 1, prefix_length: 2, prefix_match: true)
    assert_fuzzy(f, "that",       [1, 2, 3, 4, 5], max_edit_distance: 2, prefix_length: 2, prefix_match: true)
    assert_fuzzy(f, "IsThisA",    [],              max_edit_distance: 1, prefix_length: 2, prefix_match: true)
    assert_fuzzy(f, "IsThisA",    [6],             max_edit_distance: 2, prefix_length: 2, prefix_match: true)
  end

  def run_fuzzysearch_default_cased_tests(f)
    puts "Running fuzzy search tests with default parameters for cased attributes: #{f}"
    
    assert_fuzzy(f, "ThisIsAFox", [1, 2, 3])
    assert_fuzzy(f, "ThisIsAFo1", [1, 2, 3])
    assert_fuzzy(f, "ThisIsA11", [])
    assert_fuzzy(f, "ThisIs", [5])
    assert_fuzzy(f, "1hisIs", [5])
    assert_fuzzy(f, "1", [])
  end

  def teardown
    stop
  end
end
