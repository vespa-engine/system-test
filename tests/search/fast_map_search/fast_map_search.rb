# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'
require 'reindexing'

class FastMapSearch < IndexedOnlySearchTest

  include Reindexing

  CLOSED = ""
  LEFT_OPEN = "{bounds:\"leftOpen\"}"
  RIGHT_OPEN = "{bounds:\"rightOpen\"}"
  OPEN = "{bounds:\"open\"}"

  # The name given to the lookup field in 'fast-search map field', which queries must use,
  # as in my_map.lookup{"key"} = 42, to be rewritten to a fast map lookup
  LOOKUP = "lookup"

  def setup
    set_description("Tests fast map search feature")
    set_owner("johsol")
  end

  def teardown
    stop
  end

  def deploy_and_start(sd_file = "fast_map_search.sd")
    deploy_app(SearchApp.new.sd(selfdir + sd_file))
    start
  end

  # Returns the name to use in queries for the lookup field of the given field
  def lookup(field)
    "#{field}.#{LOOKUP}"
  end

  ######################################################################################################################
  # Basic tests
  ######################################################################################################################

  # Values fed by feed_and_wait and feed_arrays_and_wait. The _THREE values are in no document.
  STRING_ONE = "bar"
  STRING_TWO = "qux"
  STRING_THREE = "baz"
  INT_ONE = 42
  INT_TWO = 13
  INT_THREE = 43
  LONG_ONE = 4294967338
  LONG_TWO = 4294967309
  LONG_THREE = 4294967339
  FLOAT_ONE = 1.5
  FLOAT_TWO = 0.25
  FLOAT_THREE = 1.75
  DOUBLE_ONE = -2.5
  DOUBLE_TWO = 0.75
  DOUBLE_THREE = -2.75
  # Keys of the my_map_int_key and my_map_long_key fields, used as "foo" and "baz" in the other maps
  INT_KEYS = [7, -3]
  LONG_KEYS = [5000000000, -5000000000]

  def feed_and_wait
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0")
                                      .add_field("id", 0)
                                      .add_field("my_map_string", { "foo" => STRING_ONE })
                                      .add_field("my_map_int", { "foo" => INT_ONE })
                                      .add_field("my_map_long", { "foo" => LONG_ONE })
                                      .add_field("my_map_float", { "foo" => FLOAT_ONE })
                                      .add_field("my_map_double", { "foo" => DOUBLE_ONE })
                                      .add_field("my_map_int_key", { INT_KEYS[0] => STRING_ONE })
                                      .add_field("my_map_long_key", { LONG_KEYS[0] => STRING_ONE })
    )
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::1")
                                      .add_field("id", 1)
                                      .add_field("my_map_string", { "foo" => STRING_TWO, "baz" => STRING_ONE })
                                      .add_field("my_map_int", { "foo" => INT_TWO, "baz" => INT_ONE })
                                      .add_field("my_map_long", { "foo" => LONG_TWO, "baz" => LONG_ONE })
                                      .add_field("my_map_float", { "foo" => FLOAT_TWO, "baz" => FLOAT_ONE })
                                      .add_field("my_map_double", { "foo" => DOUBLE_TWO, "baz" => DOUBLE_ONE })
                                      .add_field("my_map_int_key", { INT_KEYS[0] => STRING_TWO, INT_KEYS[1] => STRING_ONE })
                                      .add_field("my_map_long_key", { LONG_KEYS[0] => STRING_TWO, LONG_KEYS[1] => STRING_ONE })
    )
    wait_for_hitcount('query=sddocname:fast_map_search', 2)
  end

  def test_search_basic
    deploy_and_start
    feed_and_wait

    run_queries([:map_match_query, :shortform_query], "my_map_string", STRING_ONE, STRING_THREE)

    numeric = [:map_match_query, :map_match_equals_query, :shortform_query, :shortform_equals_query]
    run_queries(numeric, "my_map_int", INT_ONE, INT_THREE)
    run_queries(numeric, "my_map_long", LONG_ONE, LONG_THREE)

    # Only the '=' spellings, which keep the value a numeric term: a quoted '1.5' is a word term,
    # which linguistics may split into '1' and '5'.
    floating_point = [:map_match_equals_query, :shortform_equals_query]
    run_queries(floating_point, "my_map_float", FLOAT_ONE, FLOAT_THREE)
    run_queries(floating_point, "my_map_double", DOUBLE_ONE, DOUBLE_THREE)

    # Integer keys are given quoted, as the string keys above
    run_queries([:map_match_query, :shortform_query], "my_map_int_key", STRING_ONE, STRING_THREE, INT_KEYS)
    run_queries([:map_match_query, :shortform_query], "my_map_long_key", STRING_ONE, STRING_THREE, LONG_KEYS)
    # and unquoted
    search_and_verify([1], unquoted_key_query(lookup("my_map_int_key"), INT_KEYS[1], STRING_ONE))
    search_and_verify([1], unquoted_key_query(lookup("my_map_long_key"), LONG_KEYS[1], STRING_ONE))
  end

  # Runs the queries made by each of the given functions on the lookup field of the given field,
  # where keys are the keys fed as "foo" and "baz" in feed_and_wait.
  def run_queries(make_query_fns, field, value_one, value_two, keys = ["foo", "baz"])
    foo, baz = keys
    make_query_fns.each do |make_query_fn|
      # A key-value pair matches only when both are present in the same map entry.
      # Document 1 contains both the key 'foo' and the value 'bar', but in different
      # entries, so it must not match.
      search_and_verify([0], public_send(make_query_fn, lookup(field), foo, value_one))
      search_and_verify([1], public_send(make_query_fn, lookup(field), baz, value_one))
      search_and_verify([], public_send(make_query_fn, lookup(field), foo, value_two))

      assert_summary(public_send(make_query_fn, lookup(field), foo, value_one), field)
    end
  end

  # The map summary is returned for the single hit, and the synthetic attribute is not part of it.
  def assert_summary(query, field)
    result = search(query)
    assert_equal(1, result.hit.size)
    summary_fields = result.hit[0].field.keys
    assert(summary_fields.include?(field), "Expected '#{field}' in the summary, got #{summary_fields}")
    assert(summary_fields.none? { |name| name.include?("$") },
           "Expected no synthetic attribute in the summary, got #{summary_fields}")
  end

  # The explicit form of a map lookup, which the fancy syntax below is short for.
  def map_match_query(field, key, value)
    yql = "select * from sources * where #{field} contains mapMatch(" +
          "key contains '#{key}', value contains '#{value}')"
    URI.encode_www_form([['yql', yql]])
  end

  # The explicit form of field{key} = value, see shortform_equals_query.
  def map_match_equals_query(field, key, value)
    yql = "select * from sources * where #{field} contains mapMatch(" +
          "key contains '#{key}', value = #{value})"
    URI.encode_www_form([['yql', yql]])
  end

  # fancy syntax: field{key} contains value.
  def shortform_query(field, key, value)
    yql = "select * from sources * where #{field}{'#{key}'} contains '#{value}'"
    URI.encode_www_form([['yql', yql]])
  end

  # fancy syntax: field{key} contains value, with an unquoted integer key.
  def unquoted_key_query(field, key, value)
    yql = "select * from sources * where #{field}{#{key}} contains '#{value}'"
    URI.encode_www_form([['yql', yql]])
  end

  # fancy syntax: field{key} = value. Unquoted, so the value stays a numeric term
  # rather than the word term the quoted 'contains' spelling produces.
  def shortform_equals_query(field, key, value)
    yql = "select * from sources * where #{field}{'#{key}'} = #{value}"
    URI.encode_www_form([['yql', yql]])
  end

  # Ranges over the values above: each _RANGE_ONE contains the _ONE value,
  # each _RANGE_TWO contains the _TWO value, and neither contains both.
  INT_RANGE_ONE = [40, 50]
  INT_RANGE_TWO = [10, 20]
  LONG_RANGE_ONE = [4294967330, 4294967350]
  LONG_RANGE_TWO = [4294967300, 4294967320]
  FLOAT_RANGE_ONE = [1.0, 2.0]
  FLOAT_RANGE_TWO = [-0.5, 0.5]
  DOUBLE_RANGE_ONE = [-3.0, -2.0]
  DOUBLE_RANGE_TWO = [0.5, 1.0]

  def test_range_basic
    deploy_and_start
    feed_and_wait

    range_queries = [:map_match_range_query, :map_range_query]
    run_range_queries(range_queries, "my_map_int", INT_RANGE_ONE, INT_RANGE_TWO)

    # The endpoints lie beyond the int range, as do the fed values.
    run_range_queries(range_queries, "my_map_long", LONG_RANGE_ONE, LONG_RANGE_TWO)

    # FLOAT_RANGE_TWO spans zero, where the encoding of the sign changes.
    run_range_queries(range_queries, "my_map_float", FLOAT_RANGE_ONE, FLOAT_RANGE_TWO)

    # DOUBLE_RANGE_ONE holds negative values only, whose encoding must be inverted to sort correctly.
    run_range_queries(range_queries, "my_map_double", DOUBLE_RANGE_ONE, DOUBLE_RANGE_TWO)
  end

  # Runs the queries made by each of the given functions on the lookup field of the given field.
  # range_one contains the 'foo' value of document 0 and the 'baz' value of document 1,
  # range_two contains the 'foo' value of document 1, and neither range contains both.
  def run_range_queries(make_query_fns, field, range_one, range_two)
    make_query_fns.each do |make_query_fn|
      # Only the entry with the queried key is considered: the two documents have different
      # 'foo' values, so a range around one of them on key 'foo' matches one document only.
      search_and_verify([0], public_send(make_query_fn, lookup(field), "foo", *range_one))
      search_and_verify([1], public_send(make_query_fn, lookup(field), "foo", *range_two))
      search_and_verify([1], public_send(make_query_fn, lookup(field), "baz", *range_one))

      # Document 1 is the only one with the key 'baz', and its 'baz' value is outside range_two.
      search_and_verify([], public_send(make_query_fn, lookup(field), "baz", *range_two))

      assert_summary(public_send(make_query_fn, lookup(field), "foo", *range_one), field)
    end
  end

  def map_match_range_query(field, key, from, to)
    yql = "select * from sources * where #{field} contains mapMatch(" +
          "key contains '#{key}', range(value, #{from}, #{to}))"
    URI.encode_www_form([['yql', yql]])
  end

  # fancy syntax: range(field{key}, from, to).
  def map_range_query(field, key, from, to)
    yql = "select * from sources * where range(#{field}{'#{key}'}, #{from}, #{to})"
    URI.encode_www_form([['yql', yql]])
  end

  ######################################################################################################################
  # Cased/uncased matching
  ######################################################################################################################

  def test_search_cased_uncased
    deploy_and_start("cased_uncased.sd")

    vespa.document_api_v1.put(Document.new("id:cased_uncased:cased_uncased::0")
                                      .add_field("string_map", { "case_does_not_matter" => "foo"})
                                      .add_field("int_map", { "case_does_not_matter" => 42})
                                      .add_field("cased_string_map", { "case_matters" => "foo", "CASE_MATTERS" => "BAR" })
                                      .add_field("cased_int_map", { "case_matters" => 42, "CASE_MATTERS" => 43 })
                                      .add_field("long_map", { "case_does_not_matter" => 4294967338})
                                      .add_field("cased_long_map", { "case_matters" => 4294967338, "CASE_MATTERS" => 4294967339 })
                                      .add_field("int_key_cased_value_map", { 7 => "foo", 8 => "BAR" })
    )
    wait_for_hitcount('query=sddocname:cased_uncased', 1)

    # The maps have struct-field attributes, so they are searchable without the rewrite too.
    # Querying the lookup field and querying the map itself must match the same.
    [ lambda { |field| lookup(field) }, lambda { |field| field } ].each do |ref|
      puts "Uncased matching"
      assert_hitcount(shortform_query(ref.call("string_map"), "case_does_not_matter", "foo"), 1)
      assert_hitcount(shortform_query(ref.call("string_map"), "case_does_not_matter", "FOO"), 1)
      assert_hitcount(shortform_query(ref.call("string_map"), "CASE_DOES_NOT_MATTER", "foo"), 1)
      assert_hitcount(shortform_query(ref.call("string_map"), "CASE_DOES_NOT_MATTER", "FOO"), 1)

      assert_hitcount(shortform_equals_query(ref.call("int_map"), "case_does_not_matter",  42), 1)
      assert_hitcount(shortform_equals_query(ref.call("int_map"), "CASE_DOES_NOT_MATTER",  42), 1)
      assert_hitcount(shortform_equals_query(ref.call("long_map"), "case_does_not_matter", 4294967338), 1)
      assert_hitcount(shortform_equals_query(ref.call("long_map"), "CASE_DOES_NOT_MATTER", 4294967338), 1)

      puts "Cased matching"
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "case_matters", "foo"), 1)
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "case_matters", "FOO"), 0)
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "case_matters", "bar"), 0)
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "case_matters", "BAR"), 0)
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "CASE_MATTERS", "foo"), 0)
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "CASE_MATTERS", "FOO"), 0)
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "CASE_MATTERS", "bar"), 0)
      assert_hitcount(shortform_query(ref.call("cased_string_map"), "CASE_MATTERS", "BAR"), 1)

      assert_hitcount(shortform_equals_query(ref.call("cased_int_map"), "case_matters", 42), 1)
      assert_hitcount(shortform_equals_query(ref.call("cased_int_map"), "case_matters", 43), 0)
      assert_hitcount(shortform_equals_query(ref.call("cased_int_map"), "CASE_MATTERS", 42), 0)
      assert_hitcount(shortform_equals_query(ref.call("cased_int_map"), "CASE_MATTERS", 43), 1)
      assert_hitcount(shortform_equals_query(ref.call("cased_long_map"), "case_matters", 4294967338), 1)
      assert_hitcount(shortform_equals_query(ref.call("cased_long_map"), "case_matters", 4294967339), 0)
      assert_hitcount(shortform_equals_query(ref.call("cased_long_map"), "CASE_MATTERS", 4294967338), 0)
      assert_hitcount(shortform_equals_query(ref.call("cased_long_map"), "CASE_MATTERS", 4294967339), 1)

      assert_hitcount(shortform_query(ref.call("int_key_cased_value_map"), 7, "foo"), 1)
      assert_hitcount(shortform_query(ref.call("int_key_cased_value_map"), 7, "FOO"), 0)
      assert_hitcount(shortform_query(ref.call("int_key_cased_value_map"), 7, "BAR"), 0)
      assert_hitcount(shortform_query(ref.call("int_key_cased_value_map"), 8, "bar"), 0)
      assert_hitcount(shortform_query(ref.call("int_key_cased_value_map"), 8, "BAR"), 1)
    end
  end

  ######################################################################################################################
  # Query rewriting
  ######################################################################################################################

  # A query on the lookup field of a field with 'fast-search map field' is rewritten by the container
  # to the synthetic key-value attribute, which the query trace names as <field>$<lookup>. A query on
  # the field itself is left alone and searches the struct-field attributes.
  def test_rewrite
    deploy_and_start
    feed_and_wait

    ["my_map_string", "my_map_int"].each do |field|
      assert_rewritten(field, "#{lookup(field)} contains mapMatch(key contains 'foo', value contains '42')")
      assert_rewritten(field, "#{lookup(field)}{'foo'} contains '42'")
      assert_rewritten(field, "#{lookup(field)}{'foo'} = 42") if field == "my_map_int"

      assert_not_rewritten(field, "#{field} contains sameElement(key contains 'foo', value contains '42')")
      assert_not_rewritten(field, "#{field}{'foo'} contains '42'")
      assert_not_rewritten(field, "#{field}{'foo'} = 42") if field == "my_map_int"
    end

    # Ranges are rewritten too, also with the hitLimit annotation (even though the hitLimit might be ignored)
    ["my_map_int", "my_map_long", "my_map_float", "my_map_double"].each do |field|
      assert_rewritten(field, "range(#{lookup(field)}{'foo'}, -10, 50)")
      assert_rewritten(field, "#{lookup(field)} contains mapMatch(key contains 'foo', range(value, -10, 50))")
      assert_rewritten(field, "({hitLimit: 1}range(#{lookup(field)}{'foo'}, -10, 50))")
      assert_rewritten(field, "({hitLimit: 1, descending: true}range(#{lookup(field)}{'foo'}, -10, 50))")

      assert_not_rewritten(field, "range(#{field}{'foo'}, -10, 50)")
      assert_not_rewritten(field, "#{field} contains sameElement(key contains 'foo', range(value, -10, 50))")
    end

    # For an array of struct, the key and value are named by the struct fields given in the schema.
    assert_rewritten("my_array_string", "#{lookup("my_array_string")} contains mapMatch(key contains 'foo', value contains 'bar')")
    assert_rewritten("my_array_string", "#{lookup("my_array_string")}{'foo'} contains 'bar'")
    assert_not_rewritten("my_array_string", "my_array_string contains sameElement(mykey contains 'foo', myvalue contains 'bar')")
  end

  def assert_rewritten(field, where)
    assert(rewritten?(field, where), "Expected query to be rewritten to a fast map lookup: #{where}")
  end

  def assert_not_rewritten(field, where)
    assert(!rewritten?(field, where), "Expected query not to be rewritten to a fast map lookup: #{where}")
  end

  def rewritten?(field, where, lookup_name = LOOKUP)
    result = search({ "yql" => "select * from sources * where #{where}", "tracelevel" => "2" })
    result.json.to_s.include?("#{field}$#{lookup_name}")
  end

  ######################################################################################################################
  # Corner cases
  ######################################################################################################################

  def test_range_int_corner_cases
    deploy_and_start

    int_min = -2147483648
    int_max = 2147483647

    # Every document gets some junk "aaa" and "zzz" values to make sure that (-)Infinity with fast map search
    # does not suddenly get you values from different keys
    [ int_min, -10, -1, 0, 1, 10, int_max ].each_with_index do |number, id|
      vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::#{id}").add_field("id", id).
                                  add_field("my_map_int", { "aaa" => -42, "number" => number, "zzz" => 42 }))
    end
    wait_for_hitcount('query=sddocname:fast_map_search', 7)

    def make_query(annotation, from, to)
      {"yql" => "select * from sources * where (#{annotation}range(#{lookup("my_map_int")}{\"number\"}, #{from.nil? ? "-Infinity" : from}, #{to.nil? ? "Infinity" : to})) order by id asc" }
    end

    # When using (-)Infinity, whether the bound is closed or not should not matter
    search_and_verify([0, 1, 2, 3, 4, 5, 6], make_query(CLOSED, nil, nil))
    search_and_verify([0, 1, 2, 3, 4, 5, 6], make_query(LEFT_OPEN, nil, nil))
    search_and_verify([0, 1, 2, 3, 4, 5, 6], make_query(RIGHT_OPEN, nil, nil))
    search_and_verify([0, 1, 2, 3, 4, 5, 6], make_query(OPEN, nil, nil))

    # When using the min/max int value, whether the bound is closed or not SHOULD matter
    search_and_verify([0, 1, 2, 3, 4, 5, 6], make_query(CLOSED, int_min, int_max))
    search_and_verify([1, 2, 3, 4, 5, 6], make_query(LEFT_OPEN, int_min, int_max))
    search_and_verify([0, 1, 2, 3, 4, 5], make_query(RIGHT_OPEN, int_min, int_max))
    search_and_verify([1, 2, 3, 4, 5], make_query(OPEN, int_min, int_max))

    # Behavior around 0
    search_and_verify([2, 3, 4], make_query(CLOSED, -1, 1))
    search_and_verify([3, 4], make_query(LEFT_OPEN, -1, 1))
    search_and_verify([2, 3], make_query(RIGHT_OPEN, -1, 1))
    search_and_verify([3], make_query(OPEN, -1, 1))

    # Behavior from -Infinity to 0
    search_and_verify([0, 1, 2, 3], make_query(CLOSED, nil, 0))
    search_and_verify([0, 1, 2, 3], make_query(LEFT_OPEN, nil, 0))
    search_and_verify([0, 1, 2], make_query(RIGHT_OPEN, nil, 0))
    search_and_verify([0, 1, 2], make_query(OPEN, nil, 0))

    # Behavior from 0 to Infinity
    search_and_verify([3, 4, 5, 6], make_query(CLOSED, 0, nil))
    search_and_verify([4, 5, 6], make_query(LEFT_OPEN, 0, nil))
    search_and_verify([3, 4, 5, 6], make_query(RIGHT_OPEN, 0, nil))
    search_and_verify([4, 5, 6], make_query(OPEN, 0, nil))
  end

  def search_and_verify(expected_ids, query)
    result = search(query)
    #puts "#{query["yql"]}"
    #puts result
    verify_ids(expected_ids, result)
  end

  def test_float_corner_cases
    verify_floating_point_corner_cases("my_map_float", "3.0e38")
  end

  # The largest value is beyond the float range, so that it would be lost if the
  # double value were encoded like a float.
  def test_double_corner_cases
    verify_floating_point_corner_cases("my_map_double", "1.0e300")
  end

  # Every query is run both on the lookup field, which is rewritten to the synthetic key-value
  # attribute, and on the map itself, which is searched through its struct-field attributes,
  # to verify that the rewrite does not change which documents match. The expected ids are
  # also given explicitly.
  def verify_floating_point_corner_cases(field, big)
    deploy_and_start

    # -0.0 and 0.0 are equal as numbers, but get different encodings in the synthetic attribute.
    # 0.1 is not exactly representable, and is rounded differently as a float and as a double.
    values = [ "-#{big}", "-1.5", "-0.0", "0.0", "0.1", "1.5", big ]

    # Every document gets some junk "aaa" and "zzz" values to make sure that (-)Infinity with fast map search
    # does not suddenly get you values from different keys
    values.each_with_index do |value, id|
      map = { "aaa" => -42.0, "number" => value.to_f, "zzz" => 42.0 }
      vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::#{id}").
                                  add_field("id", id).add_field(field, map))
    end
    wait_for_hitcount('query=sddocname:fast_map_search', values.size)

    # Single values. A zero matches both -0.0 and 0.0.
    verify_floating_point_equals([1], field, "-1.5")
    verify_floating_point_equals([2, 3], field, "0")
    verify_floating_point_equals([2, 3], field, "0.0")
    verify_floating_point_equals([2, 3], field, "-0.0")
    verify_floating_point_equals([4], field, "0.1")
    verify_floating_point_equals([5], field, "1.5")
    verify_floating_point_equals([6], field, big)
    verify_floating_point_equals([], field, "0.2")

    # When using (-)Infinity, whether the bound is closed or not should not matter
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], field, CLOSED, nil, nil)
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], field, LEFT_OPEN, nil, nil)
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], field, RIGHT_OPEN, nil, nil)
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], field, OPEN, nil, nil)

    # When using the extreme values, whether the bound is closed or not SHOULD matter
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], field, CLOSED, "-#{big}", big)
    verify_floating_point_range([1, 2, 3, 4, 5, 6], field, LEFT_OPEN, "-#{big}", big)
    verify_floating_point_range([0, 1, 2, 3, 4, 5], field, RIGHT_OPEN, "-#{big}", big)
    verify_floating_point_range([1, 2, 3, 4, 5], field, OPEN, "-#{big}", big)

    # Behavior around 0
    verify_floating_point_range([1, 2, 3, 4, 5], field, CLOSED, "-1.5", "1.5")
    verify_floating_point_range([2, 3, 4, 5], field, LEFT_OPEN, "-1.5", "1.5")
    verify_floating_point_range([1, 2, 3, 4], field, RIGHT_OPEN, "-1.5", "1.5")
    verify_floating_point_range([2, 3, 4], field, OPEN, "-1.5", "1.5")

    # Behavior from -Infinity to 0: a closed bound includes both zeros, an open bound neither.
    verify_floating_point_range([0, 1, 2, 3], field, CLOSED, nil, "0")
    verify_floating_point_range([0, 1, 2, 3], field, LEFT_OPEN, nil, "0")
    verify_floating_point_range([0, 1], field, RIGHT_OPEN, nil, "0")
    verify_floating_point_range([0, 1], field, OPEN, nil, "0")
    verify_floating_point_range([0, 1, 2, 3], field, CLOSED, nil, "-0.0")
    verify_floating_point_range([0, 1], field, RIGHT_OPEN, nil, "-0.0")

    # Behavior from 0 to Infinity
    verify_floating_point_range([2, 3, 4, 5, 6], field, CLOSED, "0", nil)
    verify_floating_point_range([4, 5, 6], field, LEFT_OPEN, "0", nil)
    verify_floating_point_range([2, 3, 4, 5, 6], field, RIGHT_OPEN, "0", nil)
    verify_floating_point_range([4, 5, 6], field, OPEN, "0", nil)
    verify_floating_point_range([2, 3, 4, 5, 6], field, CLOSED, "-0.0", nil)
    verify_floating_point_range([4, 5, 6], field, LEFT_OPEN, "-0.0", nil)

    # An endpoint which is not exactly representable is rounded like the stored value
    verify_floating_point_range([4], field, CLOSED, "0.1", "0.1")
    verify_floating_point_range([4, 5], field, CLOSED, "0.1", "1.5")
    verify_floating_point_range([5], field, LEFT_OPEN, "0.1", "1.5")
    verify_floating_point_range([4], field, RIGHT_OPEN, "0.1", "1.5")
    verify_floating_point_range([], field, OPEN, "0.1", "1.5")
  end

  def verify_floating_point_equals(expected_ids, field, value)
    [lookup(field), field].each do |f|
      search_and_verify(expected_ids,
                        {"yql" => "select * from sources * where #{f}{\"number\"} = #{value} order by id asc"})
    end
  end

  def verify_floating_point_range(expected_ids, field, annotation, from, to)
    [lookup(field), field].each do |f|
      search_and_verify(expected_ids,
                        {"yql" => "select * from sources * where (#{annotation}range(#{f}{\"number\"}, " +
                                  "#{from.nil? ? "-Infinity" : from}, #{to.nil? ? "Infinity" : to})) order by id asc"})
    end
  end

  def verify_ids(expected_ids, result)
    expected_ids_array = Array(expected_ids)
    got_ids_array = result.hit.map{ |hit| hit.field["id"] }
    assert_equal(expected_ids_array, got_ids_array)
  end

  ######################################################################################################################
  # Arrays of struct
  ######################################################################################################################

  # Returns an element of the my_array_<type> fields, which are arrays of struct { mykey, myvalue }.
  def element(key, value)
    { "mykey" => key, "myvalue" => value }
  end

  # Document 0 holds the _ONE value under the key 'foo'.
  # Document 1 holds the _TWO value under the key 'foo', and the _ONE value under the key 'baz'.
  # Document 2 holds the key 'foo' twice, which a map cannot, with the _ONE and the _TWO value.
  def feed_arrays_and_wait
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0")
                                .add_field("id", 0)
                                .add_field("my_array_string", [ element("foo", STRING_ONE) ])
                                .add_field("my_array_int",    [ element("foo", INT_ONE) ])
                                .add_field("my_array_long",   [ element("foo", LONG_ONE) ])
    )
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::1")
                                .add_field("id", 1)
                                .add_field("my_array_string", [ element("foo", STRING_TWO), element("baz", STRING_ONE) ])
                                .add_field("my_array_int",    [ element("foo", INT_TWO),    element("baz", INT_ONE) ])
                                .add_field("my_array_long",   [ element("foo", LONG_TWO),   element("baz", LONG_ONE) ])
    )
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::2")
                                .add_field("id", 2)
                                .add_field("my_array_string", [ element("foo", STRING_ONE), element("foo", STRING_TWO) ])
                                .add_field("my_array_int",    [ element("foo", INT_ONE),    element("foo", INT_TWO) ])
                                .add_field("my_array_long",   [ element("foo", LONG_ONE),   element("foo", LONG_TWO) ])
    )
    wait_for_hitcount('query=sddocname:fast_map_search', 3)
  end

  def test_array_of_struct
    deploy_and_start
    feed_arrays_and_wait

    # Strings
    verify_array_contains([0, 2], "my_array_string", "foo", STRING_ONE)
    verify_array_contains([1, 2], "my_array_string", "foo", STRING_TWO)
    verify_array_contains([1],    "my_array_string", "baz", STRING_ONE)
    verify_array_contains([],     "my_array_string", "baz", STRING_TWO)

    # Ints
    verify_array_contains([0, 2], "my_array_int", "foo", INT_ONE)
    verify_array_contains([1, 2], "my_array_int", "foo", INT_TWO)
    verify_array_contains([1],    "my_array_int", "baz", INT_ONE)
    verify_array_contains([],     "my_array_int", "baz", INT_TWO)

    verify_array_equals([0, 2], "my_array_int", "foo", INT_ONE)
    verify_array_equals([1, 2], "my_array_int", "foo", INT_TWO)
    verify_array_equals([1],    "my_array_int", "baz", INT_ONE)
    verify_array_equals([],     "my_array_int", "baz", INT_TWO)

    verify_array_range([0, 2], "my_array_int", "foo", INT_RANGE_ONE)
    verify_array_range([1, 2], "my_array_int", "foo", INT_RANGE_TWO)
    verify_array_range([1],    "my_array_int", "baz", INT_RANGE_ONE)
    verify_array_range([],     "my_array_int", "baz", INT_RANGE_TWO)

    # Longs
    verify_array_contains([0, 2], "my_array_long", "foo", LONG_ONE)
    verify_array_contains([1, 2], "my_array_long", "foo", LONG_TWO)
    verify_array_contains([1],    "my_array_long", "baz", LONG_ONE)
    verify_array_contains([],     "my_array_long", "baz", LONG_TWO)

    verify_array_equals([0, 2], "my_array_long", "foo", LONG_ONE)
    verify_array_equals([1, 2], "my_array_long", "foo", LONG_TWO)
    verify_array_equals([1],    "my_array_long", "baz", LONG_ONE)
    verify_array_equals([],     "my_array_long", "baz", LONG_TWO)

    verify_array_range([0, 2], "my_array_long", "foo", LONG_RANGE_ONE)
    verify_array_range([1, 2], "my_array_long", "foo", LONG_RANGE_TWO)
    verify_array_range([1],    "my_array_long", "baz", LONG_RANGE_ONE)
    verify_array_range([],     "my_array_long", "baz", LONG_RANGE_TWO)
  end

  # Searches for elements with the given key and value with a map lookup on the lookup field of the
  # array, both in the explicit mapMatch form and in the fancy syntax, and with the equivalent
  # sameElement query on the array itself. All must match the documents with the given ids.
  def verify_array_contains(expected_ids, field, key, value)
    verify_array_query(expected_ids, "#{lookup(field)} contains mapMatch(key contains '#{key}', value contains '#{value}')")
    verify_array_query(expected_ids, "#{lookup(field)}{'#{key}'} contains '#{value}'")
    verify_array_query(expected_ids, "#{field} contains sameElement(mykey contains '#{key}', myvalue contains '#{value}')")
  end

  # Searches for elements with the given key and numeric value with '=' instead of 'contains',
  # in the same three ways as verify_array_contains. The value is not quoted, so it stays a number.
  def verify_array_equals(expected_ids, field, key, value)
    verify_array_query(expected_ids, "#{lookup(field)} contains mapMatch(key contains '#{key}', value = #{value})")
    verify_array_query(expected_ids, "#{lookup(field)}{'#{key}'} = #{value}")
    verify_array_query(expected_ids, "#{field} contains sameElement(mykey contains '#{key}', myvalue = #{value})")
  end

  # Searches for elements with the given key and a value in the given range, in the same three ways
  # as verify_array_contains.
  def verify_array_range(expected_ids, field, key, range)
    from, to = range
    verify_array_query(expected_ids, "#{lookup(field)} contains mapMatch(key contains '#{key}', range(value, #{from}, #{to}))")
    verify_array_query(expected_ids, "range(#{lookup(field)}{'#{key}'}, #{from}, #{to})")
    verify_array_query(expected_ids, "#{field} contains sameElement(mykey contains '#{key}', range(myvalue, #{from}, #{to}))")
  end

  def verify_array_query(expected_ids, where)
    search_and_verify(expected_ids, { "yql" => "select * from sources * where #{where} order by id asc" })
  end

  # A field may have several 'fast-search map field' lookups, each with its own attribute. The 'reversed'
  # lookup of my_array_string has the struct fields swapped, so it finds the key by the value.
  def test_several_lookups_per_field
    deploy_and_start
    feed_arrays_and_wait

    verify_array_query([0, 2], "my_array_string.lookup{'foo'} contains '#{STRING_ONE}'")
    verify_array_query([0, 2], "my_array_string.reversed{'#{STRING_ONE}'} contains 'foo'")
    verify_array_query([1, 2], "my_array_string.reversed{'#{STRING_TWO}'} contains 'foo'")
    verify_array_query([1],    "my_array_string.reversed{'#{STRING_ONE}'} contains 'baz'")
    verify_array_query([],     "my_array_string.reversed{'#{STRING_TWO}'} contains 'baz'")
    verify_array_query([],     "my_array_string.reversed{'foo'} contains '#{STRING_ONE}'")

    # Each lookup is rewritten to its own attribute
    where = "my_array_string.reversed{'#{STRING_ONE}'} contains 'foo'"
    assert(rewritten?("my_array_string", where, "reversed"), "Expected query to be rewritten to the reversed lookup: #{where}")
    assert(!rewritten?("my_array_string", where, "lookup"), "Expected query not to be rewritten to the lookup: #{where}")
    where = "my_array_string.lookup{'foo'} contains '#{STRING_ONE}'"
    assert(rewritten?("my_array_string", where, "lookup"), "Expected query to be rewritten to the lookup: #{where}")
    assert(!rewritten?("my_array_string", where, "reversed"), "Expected query not to be rewritten to the reversed lookup: #{where}")
  end

  # A field path update into one array element would leave the synthetic key-value attribute
  # holding only the updated element, so it is rejected, as for maps.
  def test_array_of_struct_element_assign_rejected
    deploy_and_start
    elements = [ { "mykey" => "foo", "myvalue" => "stale" } ]
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0").add_field("my_array_string", elements))
    wait_for_hitcount('query=sddocname:fast_map_search', 1)

    update_file = write_json("update_array_element.json", <<~JSON)
      [
        {
          "update": "id:fast_map_search:fast_map_search::0",
          "fields": {
            "my_array_string[0]": { "assign": { "mykey": "foo", "myvalue": "bar" } }
          }
        }
      ]
    JSON
    output = feed(:file => update_file, :exceptiononfailure => false, :stderr => true)

    assert_match(/Field 'my_array_string' has 'fast-search map field', which does not support field path updates/, output)
    assert_equal(elements, vespa.document_api_v1.get("id:fast_map_search:fast_map_search::0").fields["my_array_string"])
  end

  ######################################################################################################################
  # Deletion and partial updates
  ######################################################################################################################

  # Removing a document must remove its entries from the synthetic key-value attribute,
  # and must leave the entries of the remaining documents alone.
  def test_document_removal
    deploy_and_start
    feed_and_wait

    # The value 'bar' sits under key 'foo' in document 0 and under key 'baz' in document 1.
    assert_hitcount(map_match_query(lookup("my_map_string"), "foo", "bar"), 1)
    assert_hitcount(map_match_query(lookup("my_map_string"), "baz", "bar"), 1)

    vespa.document_api_v1.remove("id:fast_map_search:fast_map_search::0")
    wait_for_hitcount('query=sddocname:fast_map_search', 1)

    assert_hitcount(map_match_query(lookup("my_map_string"), "foo", "bar"), 0)
    assert_hitcount(map_match_query(lookup("my_map_string"), "baz", "bar"), 1)
    assert_hitcount(shortform_query(lookup("my_map_string"), "foo", "bar"), 0)
    assert_hitcount(shortform_query(lookup("my_map_string"), "baz", "bar"), 1)

    vespa.document_api_v1.remove("id:fast_map_search:fast_map_search::1")
    wait_for_hitcount('query=sddocname:fast_map_search', 0)

    assert_hitcount(map_match_query(lookup("my_map_string"), "baz", "bar"), 0)
    assert_hitcount(shortform_query(lookup("my_map_string"), "baz", "bar"), 0)
  end

  # A partial update must reach the synthetic key-value attribute, not only the summary.
  def test_partial_update_assign
    deploy_and_start

    # Both documents start out with the value 'stale' under every key, so none of the
    # queries below match before the updates are applied.
    feed_file = write_json("feed_before_update.json", <<~JSON)
      [
        {
          "id": "id:fast_map_search:fast_map_search::0",
          "fields": {
            "my_map_string": { "foo": "stale" }
          }
        },
        {
          "id": "id:fast_map_search:fast_map_search::1",
          "fields": {
            "my_map_string": { "foo": "stale", "baz": "stale" }
          }
        }
      ]
    JSON
    feed_and_wait_for_docs("fast_map_search", 2, :file => feed_file)
    assert_hitcount(map_match_query(lookup("my_map_string"), "foo", "bar"), 0)
    assert_hitcount(map_match_query(lookup("my_map_string"), "baz", "bar"), 0)
    assert_hitcount(map_match_query(lookup("my_map_string"), "foo", "stale"), 2)

    # Assign the whole map field on both documents.
    update_file = write_json("update_assign.json", <<~JSON)
      [
        {
          "update": "id:fast_map_search:fast_map_search::0",
          "fields": {
            "my_map_string": { "assign": { "foo": "bar" } }
          }
        },
        {
          "update": "id:fast_map_search:fast_map_search::1",
          "fields": {
            "my_map_string": { "assign": { "foo": "qux", "baz": "bar" } }
          }
        }
      ]
    JSON
    feed(:file => update_file)
    wait_for_hitcount(map_match_query(lookup("my_map_string"), "foo", "bar"), 1)

    # The old values are gone from the attribute: a stale posting would still match here.
    assert_hitcount(map_match_query(lookup("my_map_string"), "foo", "stale"), 0)
    assert_hitcount(map_match_query(lookup("my_map_string"), "baz", "stale"), 0)

    assert_hitcount(public_send(:shortform_query, lookup("my_map_string"), "foo", "bar"), 1)
    assert_hitcount(public_send(:shortform_query, lookup("my_map_string"), "baz", "bar"), 1)
    assert_hitcount(public_send(:shortform_query, lookup("my_map_string"), "foo", "baz"), 0)
  end

  def test_entry_level_assign_rejected
    deploy_and_start
    feed_file = write_json("feed_entry_update.json", <<~JSON)
      [
        {
          "id": "id:fast_map_search:fast_map_search::0",
          "fields": {
            "my_map_string": { "foo": "stale", "baz": "keep" }
          }
        }
      ]
    JSON
    feed_and_wait_for_docs("fast_map_search", 1, :file => feed_file)
    assert_equal({ "foo" => "stale", "baz" => "keep" }, stored_map)

    # Assign a single map entry, which is a field path update.
    update_file = write_json("update_assign_entry.json", <<~JSON)
      [
        {
          "update": "id:fast_map_search:fast_map_search::0",
          "fields": {
            "my_map_string{foo}": { "assign": "bar" }
          }
        }
      ]
    JSON
    output = feed(:file => update_file, :exceptiononfailure => false, :stderr => true)

    assert_match(/Field 'my_map_string' has 'fast-search map field', which does not support field path updates/, output)
    assert_equal({ "foo" => "stale", "baz" => "keep" }, stored_map)
  end

  # Writes the given JSON to a file in the temporary directory, and returns its path
  def write_json(name, json)
    json_file = "#{dirs.tmpdir}#{name}"
    File.write(json_file, json)
    json_file
  end

  def stored_map
    vespa.document_api_v1.get("id:fast_map_search:fast_map_search::0").fields["my_map_string"]
  end

  ######################################################################################################################
  # Redeployment and reindexing
  ######################################################################################################################

  def redeploy_schema(with_lookup)
    <<~SD
      schema fast_map_search {
        field indexed_at_seconds type long {
          indexing: now | attribute
        }
        document fast_map_search {
          field id type int {
            indexing: attribute | summary
          }
          field my_map_int type map<string, int> {
            indexing: summary
            #{with_lookup ? "fast-search map field: #{LOOKUP}" : ""}
            struct-field key { indexing: attribute }
            struct-field value { indexing: attribute }
          }
        }
      }
    SD
  end

  def test_redeploy_and_reindexing
    deploy_app(SearchApp.new.sd(write_sd(redeploy_schema(false))))
    start

    # Document 0 holds INT_ONE under 'foo', and document 1 holds INT_TWO under 'foo' and INT_ONE under 'baz'
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0")
                                      .add_field("id", 0)
                                      .add_field("my_map_int", { "foo" => INT_ONE }))
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::1")
                                      .add_field("id", 1)
                                      .add_field("my_map_int", { "foo" => INT_TWO, "baz" => INT_ONE }))
    wait_for_hitcount('query=sddocname:fast_map_search', 2)
    verify_lookup([0], "my_map_int", "foo", INT_ONE)
    verify_lookup([1], "my_map_int", "baz", INT_ONE)

    puts "Redeploying with a lookup field on my_map_int"
    app = SearchApp.new.sd(write_sd(redeploy_schema(true)))
    deploy_output = redeploy(app)
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))

    # The config server marks the document type for reindexing when the attribute is added, but the cluster
    # controller learns of that only through config built on a later deployment, so nothing is reindexed yet.
    puts "Querying after redeployment, before reindexing"
    assert_rewritten("my_map_int", "#{lookup("my_map_int")}{'foo'} = #{INT_ONE}")
    verify_lookup([0], "my_map_int", "foo", INT_ONE)
    verify_lookup([1], "my_map_int", "baz", INT_ONE)
    verify_lookup([], lookup("my_map_int"), "foo", INT_ONE)
    verify_lookup([], lookup("my_map_int"), "baz", INT_ONE)

    # Document 2, fed after the redeployment, holds INT_ONE under 'foo' like document 0, but the lookup finds it
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::2")
                                      .add_field("id", 2)
                                      .add_field("my_map_int", { "foo" => INT_ONE }))
    wait_for_hitcount('query=sddocname:fast_map_search', 3)
    verify_lookup([0, 2], "my_map_int", "foo", INT_ONE)
    verify_lookup([2], lookup("my_map_int"), "foo", INT_ONE)

    puts "Triggering reindexing"
    ready = trigger_reindexing(app)
    wait_for_reindexing(ready)

    # Every document is in the attribute now, so the lookup field and the map itself match the same
    puts "Querying after reindexing"
    assert_documents_reindexed_after(ready["search"]["fast_map_search"], 3, field: "indexed_at_seconds")
    [lookup("my_map_int"), "my_map_int"].each do |field|
      verify_lookup([0, 2], field, "foo", INT_ONE)
      verify_lookup([1], field, "baz", INT_ONE)
      verify_lookup([1], field, "foo", INT_TWO)
      verify_lookup([], field, "baz", INT_TWO)
    end
  end

  # Verifies that field{key} = value matches the documents with the given ids, where field is a map or its lookup field
  def verify_lookup(expected_ids, field, key, value)
    search_and_verify(expected_ids,
                      { "yql" => "select * from sources * where #{field}{'#{key}'} = #{value} order by id asc" })
  end

  ######################################################################################################################
  # Test that invalid setups are rejected (deployment fails)
  ######################################################################################################################

  def write_sd(schema)
    sd_file = "#{dirs.tmpdir}fast_map_search.sd"
    File.write(sd_file, schema)
    sd_file
  end

  def test_rejected_setups
    check_old_syntax_deployment_fails
    check_cased_key_only_deployment_fails
    check_cased_value_only_deployment_fails
    check_array_of_struct_without_key_and_value_deployment_fails
    check_array_of_struct_with_unknown_key_deployment_fails
  end

  def assert_deploy_app_fail(application)
    begin
      deploy_app(application)
    rescue ExecuteError => e
      return
    end
    assert(nil, "Expected deployment to fail")
  end

  # The old syntax, before the lookup field was named, is gone
  def check_old_syntax_deployment_fails
    schema = <<~SD
      schema fast_map_search {
        document fast_map_search {
          field my_map type map<string, string> {
            indexing: summary
            map: fast-search
          }
        }
      }
    SD
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(schema)))
  end

  def check_cased_key_only_deployment_fails
    schema = <<~SD
      schema fast_map_search {
        document fast_map_search {
          field cased_key_only type map<string, string> {
            indexing: summary
            fast-search map field: lookup
            struct-field key {
              indexing: attribute
              match: cased
            }
            struct-field value { indexing: attribute }
          }
        }
      }
    SD
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(schema)))
  end

  def check_cased_value_only_deployment_fails
    schema = <<~SD
      schema fast_map_search {
        document fast_map_search {
          field cased_value_only type map<string, string> {
            indexing: summary
            fast-search map field: lookup
            struct-field key { indexing: attribute }
            struct-field value {
              indexing: attribute
              match: cased
            }
          }
        }
      }
    SD
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(schema)))
  end

  def check_array_of_struct_without_key_and_value_deployment_fails
    schema = <<~SD
      schema fast_map_search {
        document fast_map_search {
          struct entry {
            field mykey type string { }
            field myvalue type string { }
          }
          field my_array type array<entry> {
            indexing: summary
            fast-search map field: lookup
          }
        }
      }
    SD
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(schema)))
  end

  def check_array_of_struct_with_unknown_key_deployment_fails
    schema = <<~SD
      schema fast_map_search {
        document fast_map_search {
          struct entry {
            field mykey type string { }
            field myvalue type string { }
          }
          field my_array type array<entry> {
            indexing: summary
            fast-search map field: lookup {
              key: nokey
              value: myvalue
            }
          }
        }
      }
    SD
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(schema)))
  end

end
