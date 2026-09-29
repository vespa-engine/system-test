# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'
require 'json'

class FastMapSearch < IndexedOnlySearchTest
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
  # Search tests
  ######################################################################################################################

  # Values of the maps fed by feed_and_wait. The _THREE values are in no document.
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

  def feed_and_wait
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0")
                                      .add_field("id", 0)
                                      .add_field("my_map_string", { "foo" => STRING_ONE })
                                      .add_field("my_map_int", { "foo" => INT_ONE })
                                      .add_field("my_map_long", { "foo" => LONG_ONE })
                                      .add_field("my_map_float", { "foo" => FLOAT_ONE })
                                      .add_field("my_map_double", { "foo" => DOUBLE_ONE })
    )
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::1")
                                      .add_field("id", 1)
                                      .add_field("my_map_string", { "foo" => STRING_TWO, "baz" => STRING_ONE })
                                      .add_field("my_map_int", { "foo" => INT_TWO, "baz" => INT_ONE })
                                      .add_field("my_map_long", { "foo" => LONG_TWO, "baz" => LONG_ONE })
                                      .add_field("my_map_float", { "foo" => FLOAT_TWO, "baz" => FLOAT_ONE })
                                      .add_field("my_map_double", { "foo" => DOUBLE_TWO, "baz" => DOUBLE_ONE })
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
  end

  # Runs the queries made by each of the given functions on the lookup field of the given field.
  def run_queries(make_query_fns, field, value_one, value_two)
    make_query_fns.each do |make_query_fn|
      # A key-value pair matches only when both are present in the same map entry.
      # Document 1 contains both the key 'foo' and the value 'bar', but in different
      # entries, so it must not match.
      search_and_verify([0], public_send(make_query_fn, lookup(field), "foo", value_one))
      search_and_verify([1], public_send(make_query_fn, lookup(field), "baz", value_one))
      search_and_verify([], public_send(make_query_fn, lookup(field), "foo", value_two))

      assert_summary(public_send(make_query_fn, lookup(field), "foo", value_one), field)
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

  # fancy syntax: field{key} = value. Unquoted, so the value stays a numeric term
  # rather than the word term the quoted 'contains' spelling produces.
  def shortform_equals_query(field, key, value)
    yql = "select * from sources * where #{field}{'#{key}'} = #{value}"
    URI.encode_www_form([['yql', yql]])
  end

  def test_search_cased_uncased
    deploy_and_start("cased_uncased.sd")

    vespa.document_api_v1.put(Document.new("id:cased_uncased:cased_uncased::0")
                                      .add_field("string_map", { "case_does_not_matter" => "foo"})
                                      .add_field("int_map", { "case_does_not_matter" => 42})
                                      .add_field("cased_string_map", { "case_matters" => "foo", "CASE_MATTERS" => "BAR" })
                                      .add_field("cased_int_map", { "case_matters" => 42, "CASE_MATTERS" => 43 })
                                      .add_field("long_map", { "case_does_not_matter" => 4294967338})
                                      .add_field("cased_long_map", { "case_matters" => 4294967338, "CASE_MATTERS" => 4294967339 })
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

  def rewritten?(field, where)
    result = search({ "yql" => "select * from sources * where #{where}", "tracelevel" => "2" })
    result.json.to_s.include?("#{field}$#{LOOKUP}")
  end

  ######################################################################################################################
  # Range search
  ######################################################################################################################

  def test_range_basic
    deploy_and_start
    feed_and_wait

    range_queries = [:map_match_range_query, :map_range_query]
    run_range_queries(range_queries, "my_map_int", [40, 50], [10, 20])

    # The endpoints lie beyond the int range, as do the fed values.
    run_range_queries(range_queries, "my_map_long", [4294967330, 4294967350], [4294967300, 4294967320])

    # range_two spans zero, where the encoding of the sign changes.
    run_range_queries(range_queries, "my_map_float", [1.0, 2.0], [-0.5, 0.5])

    # range_one holds negative values only, whose encoding must be inverted to sort correctly.
    run_range_queries(range_queries, "my_map_double", [-3.0, -2.0], [0.5, 1.0])
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

  ######################################################################################################################
  # Floating point values
  ######################################################################################################################

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

  # For each value type of the my_array_<type> fields in fast_map_search.sd: the values under key 'foo'
  # in the documents fed by feed_arrays_and_wait, a range containing only the first value, and a range
  # containing only the second.
  ARRAY_VALUES = {
    "string" => { :one => "bar", :two => "qux" },
    "int"    => { :one => 42, :two => 13, :range_one => [40, 50], :range_two => [10, 20] },
    "long"   => { :one => 4294967338, :two => 4294967309,
                  :range_one => [4294967330, 4294967350], :range_two => [4294967300, 4294967320] }
  }

  def feed_arrays_and_wait
    # Document 1 holds the first value, but under the key 'baz', so it must only match on 'baz'.
    # Document 2 holds the key 'foo' twice, which a map cannot, and matches both values under it.
    docs = [
      lambda { |v| [ { "mykey" => "foo", "myvalue" => v[:one] } ] },
      lambda { |v| [ { "mykey" => "foo", "myvalue" => v[:two] }, { "mykey" => "baz", "myvalue" => v[:one] } ] },
      lambda { |v| [ { "mykey" => "foo", "myvalue" => v[:one] }, { "mykey" => "foo", "myvalue" => v[:two] } ] }
    ]
    docs.each_with_index do |elements, id|
      doc = Document.new("id:fast_map_search:fast_map_search::#{id}").add_field("id", id)
      ARRAY_VALUES.each do |type, values|
        doc.add_field("my_array_#{type}", elements.call(values))
      end
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('query=sddocname:fast_map_search', docs.size)
  end

  def test_array_of_struct
    deploy_and_start
    feed_arrays_and_wait

    ARRAY_VALUES.each do |type, values|
      verify_array_query([0, 2], type, lambda { |v| "#{v} contains '#{values[:one]}'" }, "foo")
      verify_array_query([1, 2], type, lambda { |v| "#{v} contains '#{values[:two]}'" }, "foo")
      verify_array_query([1], type, lambda { |v| "#{v} contains '#{values[:one]}'" }, "baz")
      verify_array_query([], type, lambda { |v| "#{v} contains '#{values[:two]}'" }, "baz")
      next unless values[:range_one]

      verify_array_query([0, 2], type, lambda { |v| "range(#{v}, #{values[:range_one].join(', ')})" }, "foo")
      verify_array_query([1, 2], type, lambda { |v| "range(#{v}, #{values[:range_two].join(', ')})" }, "foo")
      verify_array_query([1], type, lambda { |v| "range(#{v}, #{values[:range_one].join(', ')})" }, "baz")
      verify_array_query([], type, lambda { |v| "range(#{v}, #{values[:range_two].join(', ')})" }, "baz")
    end

    # The fancy syntax works on the lookup field of an array too
    search_and_verify([0, 2], { "yql" => "select * from sources * where #{lookup("my_array_string")}{'foo'} contains 'bar' order by id asc" })
  end

  # Runs a map lookup on the lookup field of the array, and the equivalent sameElement query on the
  # array itself, which must match the same documents. The value condition is made for the given
  # value field name.
  def verify_array_query(expected_ids, type, value_condition, key)
    field = "my_array_#{type}"
    [ "#{lookup(field)} contains mapMatch(key contains '#{key}', #{value_condition.call("value")})",
      "#{field} contains sameElement(mykey contains '#{key}', #{value_condition.call("myvalue")})" ].each do |where|
      search_and_verify(expected_ids, { "yql" => "select * from sources * where #{where} order by id asc" })
    end
  end

  # A field path update into one array element would leave the synthetic key-value attribute
  # holding only the updated element, so it is rejected, as for maps.
  def test_array_of_struct_element_assign_rejected
    deploy_and_start
    elements = [ { "mykey" => "foo", "myvalue" => "stale" } ]
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0").add_field("my_array_string", elements))
    wait_for_hitcount('query=sddocname:fast_map_search', 1)

    update_file = "#{dirs.tmpdir}update_array_element.json"
    File.write(update_file, JSON.generate([ { "update" => "id:fast_map_search:fast_map_search::0",
                                              "fields" => { "my_array_string[0]" => { "assign" => { "mykey" => "foo",
                                                                                                    "myvalue" => "bar" } } } } ]))
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
    feed_and_wait_for_docs("fast_map_search", 2, :file => selfdir+"feed_before_update.json")
    assert_hitcount(map_match_query(lookup("my_map_string"), "foo", "bar"), 0)
    assert_hitcount(map_match_query(lookup("my_map_string"), "baz", "bar"), 0)
    assert_hitcount(map_match_query(lookup("my_map_string"), "foo", "stale"), 2)

    # Assign the whole map field on both documents, leaving them in exactly the state that
    # feed.json puts them in, so the shared assertions and the summary comparison can be
    # reused as is.
    feed(:file => selfdir+"update_assign.json")
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
    feed_and_wait_for_docs("fast_map_search", 1, :file => selfdir+"feed_entry_update.json")
    assert_equal({ "foo" => "stale", "baz" => "keep" }, stored_map)

    output = feed(:file => selfdir+"update_assign_entry.json",
                  :exceptiononfailure => false, :stderr => true)

    assert_match(/Field 'my_map_string' has 'fast-search map field', which does not support field path updates/, output)
    assert_equal({ "foo" => "stale", "baz" => "keep" }, stored_map)
  end

  def stored_map
    vespa.document_api_v1.get("id:fast_map_search:fast_map_search::0").fields["my_map_string"]
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
