# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'
require 'json'

class FastMapSearch < IndexedOnlySearchTest
  CLOSED = ""
  LEFT_OPEN = "{bounds:\"leftOpen\"}"
  RIGHT_OPEN = "{bounds:\"rightOpen\"}"
  OPEN = "{bounds:\"open\"}"

  def setup
    set_description("Tests fast map search feature")
    set_owner("johsol")
  end

  def teardown
    stop
  end

  def write_sd(fields)
    sd_file = "#{dirs.tmpdir}fast_map_search.sd"
    File.write(sd_file, <<~SD)
      schema fast_map_search {
        document fast_map_search {
          #{fields}
        }
      }
    SD
    sd_file
  end

  ######################################################################################################################
  # Search tests
  ######################################################################################################################

  MY_FIELDS = <<~FIELDS
      field my_map_string type map<string, string> {
        indexing: summary
        map: fast-search
      }
      field my_map_int type map<string, int> {
        indexing: summary
        map: fast-search
      }
      field my_map_long type map<string, long> {
        indexing: summary
        map: fast-search
      }
      field my_map_float type map<string, float> {
        indexing: summary
        map: fast-search
      }
      field my_map_double type map<string, double> {
        indexing: summary
        map: fast-search
      }
    FIELDS

  def feed_and_wait
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0")
                                      .add_field("my_map_string", { "foo" => "bar" })
                                      .add_field("my_map_int", { "foo" => 42 })
                                      .add_field("my_map_long", { "foo" => 4294967338 })
                                      .add_field("my_map_float", { "foo" => 1.5 })
                                      .add_field("my_map_double", { "foo" => -2.5 })
    )
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::1")
                                      .add_field("my_map_string", { "foo" => "qux", "baz" => "bar" })
                                      .add_field("my_map_int", { "foo" => 13, "baz" => 42 })
                                      .add_field("my_map_long", { "foo" => 4294967309, "baz" => 4294967338 })
                                      .add_field("my_map_float", { "foo" => 0.25, "baz" => 1.5 })
                                      .add_field("my_map_double", { "foo" => 0.75, "baz" => -2.5 })
    )
    wait_for_hitcount('query=sddocname:fast_map_search', 2)
  end

  def test_search_basic
    deploy_app(SearchApp.new.sd(write_sd(MY_FIELDS)))
    start
    feed_and_wait

    run_queries(:same_element_query, "my_map_string", "bar", "baz", "result.json")
    run_queries(:shortform_query, "my_map_string", "bar", "baz", "result.json")

    run_queries(:same_element_query, "my_map_int", 42, 43, "result.json")
    run_queries(:shortform_query, "my_map_int", 42, 43, "result.json")
    run_queries(:shortform_equals_query, "my_map_int", 42, 43, "result.json")

    run_queries(:same_element_query, "my_map_long", 4294967338, 4294967339, "result.json")
    run_queries(:shortform_query, "my_map_long", 4294967338, 4294967339, "result.json")
    run_queries(:shortform_equals_query, "my_map_long", 4294967338, 4294967339, "result.json")

    # Only the unquoted spelling: a quoted '1.5' is segmented into '1' and '5' by linguistics,
    # since the value struct-field is not an attribute, and cannot be rewritten.
    run_queries(:shortform_equals_query, "my_map_float", 1.5, 1.75, "result.json")
    run_queries(:shortform_equals_query, "my_map_double", -2.5, -2.75, "result.json")
  end

  def run_queries(make_query_fn, field, value_one, value_two, result_file)
    # A key-value pair matches only when both are present in the same map entry.
    # Document 1 contains both the key 'foo' and the value 'bar', but in different
    # entries, so it must not match.
    assert_hitcount(public_send(make_query_fn, field, "foo", value_one), 1)
    assert_hitcount(public_send(make_query_fn, field, "baz", value_one), 1)
    assert_hitcount(public_send(make_query_fn, field, "foo", value_two), 0)

    # 'map: fast-search' makes the container rewrite the sameElement operator to a
    # single lookup in the synthetic key-value attribute. Verify through the query
    # trace that the rewrite actually happened.
    result = search(public_send(make_query_fn, field, "foo", value_one, 2))
    assert_rewritten(result, field)

    # The rewrite does not change the result: the map summary is returned,
    # and the synthetic attribute is not part of it.
    assert_result(public_send(make_query_fn, field, "foo", value_one), selfdir + result_file)
  end

  def assert_rewritten(result, field)
    assert(result.json.to_s.include?("#{field}$keyvalue"), "Expected query for field '#{field}' to be rewritten to a fast map lookup")
  end

  def same_element_query(field, key, value, tracelevel = nil)
    yql = "select * from sources * where #{field} contains sameElement(" +
          "key contains '#{key}', value contains '#{value}')"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  # fancy syntax: field{key} contains value.
  def shortform_query(field, key, value, tracelevel = nil)
    yql = "select * from sources * where #{field}{'#{key}'} contains '#{value}'"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  # fancy syntax: field{key} = value. Unquoted, so the value stays a numeric term
  # rather than the word term the quoted 'contains' spelling produces.
  def shortform_equals_query(field, key, value, tracelevel = nil)
    yql = "select * from sources * where #{field}{'#{key}'} = #{value}"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  def test_search_cased_uncased
    fields = <<~FIELDS
      field string_map type map<string, string> {
        indexing: summary
        map: fast-search
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
      field cased_string_map type map<string, string> {
        indexing: summary
        map: fast-search
        struct-field key {
          indexing: attribute
          match: cased
        }
        struct-field value {
          indexing: attribute
          match: cased
        }
      }
      field int_map type map<string, int> {
        indexing: summary
        map: fast-search
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
      field cased_int_map type map<string, int> {
        indexing: summary
        map: fast-search
        struct-field key {
          indexing: attribute
          match: cased
        }
        struct-field value { indexing: attribute }
      }
      field long_map type map<string, long> {
        indexing: summary
        map: fast-search
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
      field cased_long_map type map<string, long> {
        indexing: summary
        map: fast-search
        struct-field key {
          indexing: attribute
          match: cased
        }
        struct-field value { indexing: attribute }
      }
    FIELDS
    deploy_app(SearchApp.new.sd(write_sd(fields)))
    start

    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0")
                                      .add_field("string_map", { "case_does_not_matter" => "foo"})
                                      .add_field("int_map", { "case_does_not_matter" => 42})
                                      .add_field("cased_string_map", { "case_matters" => "foo", "CASE_MATTERS" => "BAR" })
                                      .add_field("cased_int_map", { "case_matters" => 42, "CASE_MATTERS" => 43 })
                                      .add_field("long_map", { "case_does_not_matter" => 4294967338})
                                      .add_field("cased_long_map", { "case_matters" => 4294967338, "CASE_MATTERS" => 4294967339 })
    )
    wait_for_hitcount('query=sddocname:fast_map_search', 1)

    puts "Uncased matching"
    assert_hitcount(shortform_query("string_map", "case_does_not_matter", "foo"), 1)
    assert_hitcount(shortform_query("string_map", "case_does_not_matter", "FOO"), 1)
    assert_hitcount(shortform_query("string_map", "CASE_DOES_NOT_MATTER", "foo"), 1)
    assert_hitcount(shortform_query("string_map", "CASE_DOES_NOT_MATTER", "FOO"), 1)

    assert_hitcount(shortform_equals_query("int_map", "case_does_not_matter",  42), 1)
    assert_hitcount(shortform_equals_query("int_map", "CASE_DOES_NOT_MATTER",  42), 1)
    assert_hitcount(shortform_equals_query("long_map", "case_does_not_matter", 4294967338), 1)
    assert_hitcount(shortform_equals_query("long_map", "CASE_DOES_NOT_MATTER", 4294967338), 1)

    puts "Cased matching"
    assert_hitcount(shortform_query("cased_string_map", "case_matters", "foo"), 1)
    assert_hitcount(shortform_query("cased_string_map", "case_matters", "FOO"), 0)
    assert_hitcount(shortform_query("cased_string_map", "case_matters", "bar"), 0)
    assert_hitcount(shortform_query("cased_string_map", "case_matters", "BAR"), 0)
    assert_hitcount(shortform_query("cased_string_map", "CASE_MATTERS", "foo"), 0)
    assert_hitcount(shortform_query("cased_string_map", "CASE_MATTERS", "FOO"), 0)
    assert_hitcount(shortform_query("cased_string_map", "CASE_MATTERS", "bar"), 0)
    assert_hitcount(shortform_query("cased_string_map", "CASE_MATTERS", "BAR"), 1)

    assert_hitcount(shortform_equals_query("cased_int_map", "case_matters", 42), 1)
    assert_hitcount(shortform_equals_query("cased_int_map", "case_matters", 43), 0)
    assert_hitcount(shortform_equals_query("cased_int_map", "CASE_MATTERS", 42), 0)
    assert_hitcount(shortform_equals_query("cased_int_map", "CASE_MATTERS", 43), 1)
    assert_hitcount(shortform_equals_query("cased_long_map", "case_matters", 4294967338), 1)
    assert_hitcount(shortform_equals_query("cased_long_map", "case_matters", 4294967339), 0)
    assert_hitcount(shortform_equals_query("cased_long_map", "CASE_MATTERS", 4294967338), 0)
    assert_hitcount(shortform_equals_query("cased_long_map", "CASE_MATTERS", 4294967339), 1)
  end

  def check_cased_key_only_deployment_fails
    fields = <<~FIELDS
      field cased_key_only type map<string, string> {
        indexing: summary
        map: fast-search
        struct-field key {
          indexing: attribute
          match: cased
        }
        struct-field value { indexing: attribute }
      }
    FIELDS
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(fields)))
  end

  def check_cased_value_only_deployment_fails
    fields = <<~FIELDS
      field cased_value_only type map<string, string> {
        indexing: summary
        map: fast-search
        struct-field key { indexing: attribute }
        struct-field value {
          indexing: attribute
          match: cased
        }
      }
    FIELDS
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(fields)))
  end

  def assert_deploy_app_fail(application)
    begin
      deploy_app(application)
    rescue ExecuteError => e
      return
    end
    assert(nil, "Expected deployment to fail")
  end

  ######################################################################################################################
  # Range search
  ######################################################################################################################

  def test_range_basic
    deploy_app(SearchApp.new.sd(write_sd(MY_FIELDS)))
    start
    feed_and_wait

    run_range_queries(:same_element_range_query, "my_map_int", [40, 50], [10, 20], "result.json")
    run_range_queries(:map_range_query, "my_map_int", [40, 50], [10, 20], "result.json")

    # The endpoints lie beyond the int range, as do the fed values.
    run_range_queries(:same_element_range_query, "my_map_long", [4294967330, 4294967350], [4294967300, 4294967320], "result.json")
    run_range_queries(:map_range_query, "my_map_long", [4294967330, 4294967350], [4294967300, 4294967320], "result.json")

    # range_two spans zero, where the encoding of the sign changes.
    run_range_queries(:same_element_range_query, "my_map_float", [1.0, 2.0], [-0.5, 0.5], "result.json")
    run_range_queries(:map_range_query, "my_map_float", [1.0, 2.0], [-0.5, 0.5], "result.json")

    # range_one holds negative values only, whose encoding must be inverted to sort correctly.
    run_range_queries(:same_element_range_query, "my_map_double", [-3.0, -2.0], [0.5, 1.0], "result.json")
    run_range_queries(:map_range_query, "my_map_double", [-3.0, -2.0], [0.5, 1.0], "result.json")

    # Check that range search is still rewritten when using the hitLimit annotation (even though the hitLimit might be ignored)
    assert_rewritten(search({"yql" => "select * from sources * where ({hitLimit: 1}range(my_map_int{\"foo\"}, 10, 50))", "tracelevel" => "2" }), "my_map_int")
    assert_rewritten(search({"yql" => "select * from sources * where ({hitLimit: 1, descending: true}range(my_map_int{\"foo\"}, 10, 50))", "tracelevel" => "2" }), "my_map_int")

    assert_rewritten(search({"yql" => "select * from sources * where ({hitLimit: 1}range(my_map_long{\"foo\"}, 10, 4294967338))", "tracelevel" => "2" }), "my_map_long")
    assert_rewritten(search({"yql" => "select * from sources * where ({hitLimit: 1, descending: true}range(my_map_long{\"foo\"}, 10, 4294967338))", "tracelevel" => "2" }), "my_map_long")

    assert_rewritten(search({"yql" => "select * from sources * where ({hitLimit: 1}range(my_map_float{\"foo\"}, -10.0, 10.0))", "tracelevel" => "2" }), "my_map_float")
    assert_rewritten(search({"yql" => "select * from sources * where ({hitLimit: 1, descending: true}range(my_map_float{\"foo\"}, -10.0, 10.0))", "tracelevel" => "2" }), "my_map_float")
  end

  # range_one contains the 'foo' value of document 0 and the 'baz' value of document 1,
  # range_two contains the 'foo' value of document 1, and neither range contains both.
  def run_range_queries(make_query_fn, field, range_one, range_two, result_file)
    # Only the entry with the queried key is considered: the two documents have different
    # 'foo' values, so a range around one of them on key 'foo' matches one document only.
    assert_hitcount(public_send(make_query_fn, field, "foo", *range_one), 1)
    assert_hitcount(public_send(make_query_fn, field, "foo", *range_two), 1)
    assert_hitcount(public_send(make_query_fn, field, "baz", *range_one), 1)

    # Document 1 is the only one with the key 'baz', and its 'baz' value is outside range_two.
    assert_hitcount(public_send(make_query_fn, field, "baz", *range_two), 0)

    # 'map: fast-search' makes the container rewrite the range to a lexical range over the
    # synthetic key-value attribute. Verify through the query trace that it happened.
    result = search(public_send(make_query_fn, field, "foo", *range_one, 2))
    assert_rewritten(result, field)

    # The rewrite does not change the result: the map summary is returned,
    # and the synthetic attribute is not part of it.
    assert_result(public_send(make_query_fn, field, "foo", *range_one), selfdir + result_file)
  end

  def same_element_range_query(field, key, from, to, tracelevel = nil)
    yql = "select * from sources * where #{field} contains sameElement(" +
          "key contains '#{key}', range(value, #{from}, #{to}))"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  # fancy syntax: range(field{key}, from, to).
  def map_range_query(field, key, from, to, tracelevel = nil)
    yql = "select * from sources * where range(#{field}{'#{key}'}, #{from}, #{to})"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  def test_range_int_corner_cases
    fields = <<~FIELDS
      field id type int {
          indexing: attribute | summary
          attribute: fast-search
      }
      field my_map type map<string, int> {
        indexing: summary
        map: fast-search
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
    FIELDS
    deploy_app(SearchApp.new.sd(write_sd(fields)))
    start

    int_min = -2147483648
    int_max = 2147483647

    # Every document gets some junk "aaa" and "zzz" values to make sure that (-)Infinity with fast map search
    # does not suddenly get you values from different keys
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0").add_field("id", 0).add_field("my_map", { "aaa" => -42, "number" =>  int_min, "zzz" => 42 }))
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::1").add_field("id", 1).add_field("my_map", { "aaa" => -42, "number" => -10, "zzz" => 42 }))
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::2").add_field("id", 2).add_field("my_map", { "aaa" => -42, "number" => -1, "zzz" => 42 }))
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::3").add_field("id", 3).add_field("my_map", { "aaa" => -42, "number" => 0, "zzz" => 42 }))
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::4").add_field("id", 4).add_field("my_map", { "aaa" => -42, "number" => 1, "zzz" => 42 }))
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::5").add_field("id", 5).add_field("my_map", { "aaa" => -42, "number" => 10, "zzz" => 42 }))
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::6").add_field("id", 6).add_field("my_map", { "aaa" => -42, "number" => int_max, "zzz" => 42 }))
    wait_for_hitcount('query=sddocname:fast_map_search', 7)

    def make_query(annotation, from, to)
      {"yql" => "select * from sources * where (#{annotation}range(my_map{\"number\"}, #{from.nil? ? "-Infinity" : from}, #{to.nil? ? "Infinity" : to})) order by id asc" }
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
    verify_floating_point_corner_cases("float", "3.0e38")
  end

  # The largest value is beyond the float range, so that it would be lost if the
  # double value were encoded like a float.
  def test_double_corner_cases
    verify_floating_point_corner_cases("double", "1.0e300")
  end

  # Every query is run against a map with fast search and a map without it, holding the same
  # values, to verify that the rewrite to the synthetic key-value attribute does not change
  # which documents match. The expected ids are also given explicitly.
  def verify_floating_point_corner_cases(type, big)
    fields = <<~FIELDS
      field id type int {
          indexing: attribute | summary
          attribute: fast-search
      }
      field fast_map type map<string, #{type}> {
        indexing: summary
        map: fast-search
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
      field plain_map type map<string, #{type}> {
        indexing: summary
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
    FIELDS
    deploy_app(SearchApp.new.sd(write_sd(fields)))
    start

    # -0.0 and 0.0 are equal as numbers, but get different encodings in the synthetic attribute.
    # 0.1 is not exactly representable, and is rounded differently as a float and as a double.
    values = [ "-#{big}", "-1.5", "-0.0", "0.0", "0.1", "1.5", big ]

    # Every document gets some junk "aaa" and "zzz" values to make sure that (-)Infinity with fast map search
    # does not suddenly get you values from different keys
    values.each_with_index do |value, id|
      map = { "aaa" => -42.0, "number" => value.to_f, "zzz" => 42.0 }
      vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::#{id}").
                                  add_field("id", id).add_field("fast_map", map).add_field("plain_map", map))
    end
    wait_for_hitcount('query=sddocname:fast_map_search', values.size)

    # The rewrite to the synthetic key-value attribute happens, for single values and ranges.
    [ "fast_map{\"number\"} = 1.5", "range(fast_map{\"number\"}, -1.5, 1.5)" ].each do |where|
      result = search({"yql" => "select * from sources * where #{where}", "tracelevel" => "2"})
      assert_rewritten(result, "fast_map")
    end

    # Single values. A zero matches both -0.0 and 0.0.
    verify_floating_point_equals([1], "-1.5")
    verify_floating_point_equals([2, 3], "0")
    verify_floating_point_equals([2, 3], "0.0")
    verify_floating_point_equals([2, 3], "-0.0")
    verify_floating_point_equals([4], "0.1")
    verify_floating_point_equals([5], "1.5")
    verify_floating_point_equals([6], big)
    verify_floating_point_equals([], "0.2")

    # When using (-)Infinity, whether the bound is closed or not should not matter
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], CLOSED, nil, nil)
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], LEFT_OPEN, nil, nil)
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], RIGHT_OPEN, nil, nil)
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], OPEN, nil, nil)

    # When using the extreme values, whether the bound is closed or not SHOULD matter
    verify_floating_point_range([0, 1, 2, 3, 4, 5, 6], CLOSED, "-#{big}", big)
    verify_floating_point_range([1, 2, 3, 4, 5, 6], LEFT_OPEN, "-#{big}", big)
    verify_floating_point_range([0, 1, 2, 3, 4, 5], RIGHT_OPEN, "-#{big}", big)
    verify_floating_point_range([1, 2, 3, 4, 5], OPEN, "-#{big}", big)

    # Behavior around 0
    verify_floating_point_range([1, 2, 3, 4, 5], CLOSED, "-1.5", "1.5")
    verify_floating_point_range([2, 3, 4, 5], LEFT_OPEN, "-1.5", "1.5")
    verify_floating_point_range([1, 2, 3, 4], RIGHT_OPEN, "-1.5", "1.5")
    verify_floating_point_range([2, 3, 4], OPEN, "-1.5", "1.5")

    # Behavior from -Infinity to 0: a closed bound includes both zeros, an open bound neither.
    verify_floating_point_range([0, 1, 2, 3], CLOSED, nil, "0")
    verify_floating_point_range([0, 1, 2, 3], LEFT_OPEN, nil, "0")
    verify_floating_point_range([0, 1], RIGHT_OPEN, nil, "0")
    verify_floating_point_range([0, 1], OPEN, nil, "0")
    verify_floating_point_range([0, 1, 2, 3], CLOSED, nil, "-0.0")
    verify_floating_point_range([0, 1], RIGHT_OPEN, nil, "-0.0")

    # Behavior from 0 to Infinity
    verify_floating_point_range([2, 3, 4, 5, 6], CLOSED, "0", nil)
    verify_floating_point_range([4, 5, 6], LEFT_OPEN, "0", nil)
    verify_floating_point_range([2, 3, 4, 5, 6], RIGHT_OPEN, "0", nil)
    verify_floating_point_range([4, 5, 6], OPEN, "0", nil)
    verify_floating_point_range([2, 3, 4, 5, 6], CLOSED, "-0.0", nil)
    verify_floating_point_range([4, 5, 6], LEFT_OPEN, "-0.0", nil)

    # An endpoint which is not exactly representable is rounded like the stored value
    verify_floating_point_range([4], CLOSED, "0.1", "0.1")
    verify_floating_point_range([4, 5], CLOSED, "0.1", "1.5")
    verify_floating_point_range([5], LEFT_OPEN, "0.1", "1.5")
    verify_floating_point_range([4], RIGHT_OPEN, "0.1", "1.5")
    verify_floating_point_range([], OPEN, "0.1", "1.5")
  end

  def verify_floating_point_equals(expected_ids, value)
    ["fast_map", "plain_map"].each do |field|
      search_and_verify(expected_ids,
                        {"yql" => "select * from sources * where #{field}{\"number\"} = #{value} order by id asc"})
    end
  end

  def verify_floating_point_range(expected_ids, annotation, from, to)
    ["fast_map", "plain_map"].each do |field|
      search_and_verify(expected_ids,
                        {"yql" => "select * from sources * where (#{annotation}range(#{field}{\"number\"}, " +
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

  # For each value type: the values under key 'foo' in the documents fed by feed_arrays_and_wait,
  # a range containing only the first value, and a range containing only the second.
  ARRAY_VALUES = {
    "string" => { :one => "bar", :two => "qux" },
    "int"    => { :one => 42, :two => 13, :range_one => [40, 50], :range_two => [10, 20] },
    "long"   => { :one => 4294967338, :two => 4294967309,
                  :range_one => [4294967330, 4294967350], :range_two => [4294967300, 4294967320] }
  }

  # An array of struct acts as a map when the struct fields holding the key and the value are named
  # in the map block. Every fast array has a plain twin holding the same elements, which is searched
  # without the rewrite, to verify that the rewrite does not change which documents match.
  def array_of_struct_fields
    fields = <<~FIELDS
      field id type int {
        indexing: attribute | summary
      }
    FIELDS
    ARRAY_VALUES.keys.each do |type|
      fields += <<~FIELDS
        struct entry_#{type} {
          field mykey type string { }
          field myvalue type #{type} { }
        }
        field fast_#{type} type array<entry_#{type}> {
          indexing: summary
          map {
            key: mykey
            value: myvalue
            fast-search
          }
        }
        field plain_#{type} type array<entry_#{type}> {
          indexing: summary
          struct-field mykey {
            indexing: attribute
          }
          struct-field myvalue {
            indexing: attribute
          }
        }
      FIELDS
    end
    fields
  end

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
        doc.add_field("fast_#{type}", elements.call(values)).add_field("plain_#{type}", elements.call(values))
      end
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('query=sddocname:fast_map_search', docs.size)
  end

  def test_array_of_struct
    deploy_app(SearchApp.new.sd(write_sd(array_of_struct_fields)))
    start
    feed_arrays_and_wait

    ARRAY_VALUES.each do |type, values|
      verify_array_query([0, 2], type, "myvalue contains '#{values[:one]}'", "foo")
      verify_array_query([1, 2], type, "myvalue contains '#{values[:two]}'", "foo")
      verify_array_query([1], type, "myvalue contains '#{values[:one]}'", "baz")
      verify_array_query([], type, "myvalue contains '#{values[:two]}'", "baz")
      next unless values[:range_one]

      verify_array_query([0, 2], type, "range(myvalue, #{values[:range_one].join(', ')})", "foo")
      verify_array_query([1, 2], type, "range(myvalue, #{values[:range_two].join(', ')})", "foo")
      verify_array_query([1], type, "range(myvalue, #{values[:range_one].join(', ')})", "baz")
      verify_array_query([], type, "range(myvalue, #{values[:range_two].join(', ')})", "baz")
    end
  end

  # Runs the sameElement query on both the fast array and its plain twin, and verifies through
  # the query trace that only the query on the fast array was rewritten to a fast map lookup.
  def verify_array_query(expected_ids, type, value_condition, key)
    ["fast_#{type}", "plain_#{type}"].each do |field|
      yql = "select * from sources * where #{field} contains sameElement(" +
            "mykey contains '#{key}', #{value_condition}) order by id asc"
      result = search({ "yql" => yql, "tracelevel" => "2" })
      verify_ids(expected_ids, result)
      assert_equal(field.start_with?("fast_"), result.json.to_s.include?("#{field}$keyvalue"),
                   "Expected the query on #{field} to #{field.start_with?("fast_") ? "" : "not "}" +
                   "be rewritten to a fast map lookup: #{yql}")
    end
  end

  def check_array_of_struct_without_key_and_value_deployment_fails
    fields = <<~FIELDS
      struct entry {
        field mykey type string { }
        field myvalue type string { }
      }
      field my_array type array<entry> {
        indexing: summary
        map: fast-search
      }
    FIELDS
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(fields)))
  end

  def check_array_of_struct_with_unknown_key_deployment_fails
    fields = <<~FIELDS
      struct entry {
        field mykey type string { }
        field myvalue type string { }
      }
      field my_array type array<entry> {
        indexing: summary
        map {
          key: nokey
          value: myvalue
          fast-search
        }
      }
    FIELDS
    assert_deploy_app_fail(SearchApp.new.sd(write_sd(fields)))
  end

  # A field path update into one array element would leave the synthetic key-value attribute
  # holding only the updated element, so it is rejected, as for maps.
  def test_array_of_struct_element_assign_rejected
    fields = <<~FIELDS
      struct entry {
        field mykey type string { }
        field myvalue type string { }
      }
      field my_array type array<entry> {
        indexing: summary
        map {
          key: mykey
          value: myvalue
          fast-search
        }
      }
    FIELDS
    deploy_app(SearchApp.new.sd(write_sd(fields)))
    start
    elements = [ { "mykey" => "foo", "myvalue" => "stale" } ]
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0").add_field("my_array", elements))
    wait_for_hitcount('query=sddocname:fast_map_search', 1)

    update_file = "#{dirs.tmpdir}update_array_element.json"
    File.write(update_file, JSON.generate([ { "update" => "id:fast_map_search:fast_map_search::0",
                                              "fields" => { "my_array[0]" => { "assign" => { "mykey" => "foo",
                                                                                             "myvalue" => "bar" } } } } ]))
    output = feed(:file => update_file, :exceptiononfailure => false, :stderr => true)

    assert_match(/Field 'my_array' has 'map: fast-search', which does not support field path updates/, output)
    assert_equal(elements, vespa.document_api_v1.get("id:fast_map_search:fast_map_search::0").fields["my_array"])
  end

  ######################################################################################################################
  # Deletion and partial updates
  ######################################################################################################################

  # Removing a document must remove its entries from the synthetic key-value attribute,
  # and must leave the entries of the remaining documents alone.
  def test_document_removal
    deploy_app(SearchApp.new.sd(write_sd(MY_FIELDS)))
    start
    feed_and_wait

    # The value 'bar' sits under key 'foo' in document 0 and under key 'baz' in document 1.
    assert_hitcount(same_element_query("my_map_string", "foo", "bar"), 1)
    assert_hitcount(same_element_query("my_map_string", "baz", "bar"), 1)

    vespa.document_api_v1.remove("id:fast_map_search:fast_map_search::0")
    wait_for_hitcount('query=sddocname:fast_map_search', 1)

    assert_hitcount(same_element_query("my_map_string", "foo", "bar"), 0)
    assert_hitcount(same_element_query("my_map_string", "baz", "bar"), 1)
    assert_hitcount(shortform_query("my_map_string", "foo", "bar"), 0)
    assert_hitcount(shortform_query("my_map_string", "baz", "bar"), 1)

    vespa.document_api_v1.remove("id:fast_map_search:fast_map_search::1")
    wait_for_hitcount('query=sddocname:fast_map_search', 0)

    assert_hitcount(same_element_query("my_map_string", "baz", "bar"), 0)
    assert_hitcount(shortform_query("my_map_string", "baz", "bar"), 0)
  end

  # A partial update must reach the synthetic key-value attribute, not only the summary.
  def test_partial_update_assign
    fields = <<~FIELDS
      field my_map type map<string, string> {
        indexing: summary
        map: fast-search
      }
    FIELDS
    deploy_app(SearchApp.new.sd(write_sd(fields)))
    start

    # Both documents start out with the value 'stale' under every key, so none of the
    # queries below match before the updates are applied.
    feed_and_wait_for_docs("fast_map_search", 2, :file => selfdir+"feed_before_update.json")
    assert_hitcount(same_element_query("my_map", "foo", "bar"), 0)
    assert_hitcount(same_element_query("my_map", "baz", "bar"), 0)
    assert_hitcount(same_element_query("my_map", "foo", "stale"), 2)

    # Assign the whole map field on both documents, leaving them in exactly the state that
    # feed.json puts them in, so the shared assertions and the summary comparison can be
    # reused as is.
    feed(:file => selfdir+"update_assign.json")
    wait_for_hitcount(same_element_query("my_map", "foo", "bar"), 1)

    # The old values are gone from the attribute: a stale posting would still match here.
    assert_hitcount(same_element_query("my_map", "foo", "stale"), 0)
    assert_hitcount(same_element_query("my_map", "baz", "stale"), 0)

    assert_hitcount(public_send(:shortform_query, "my_map", "foo", "bar"), 1)
    assert_hitcount(public_send(:shortform_query, "my_map", "baz", "bar"), 1)
    assert_hitcount(public_send(:shortform_query, "my_map", "foo", "baz"), 0)
  end

  def test_entry_level_assign_rejected
    deploy_and_feed_map("map: fast-search")

    output = feed(:file => selfdir+"update_assign_entry.json",
                  :exceptiononfailure => false, :stderr => true)

    assert_match(/Field 'my_map' has 'map: fast-search', which does not support field path updates/, output)
    assert_equal({ "foo" => "stale", "baz" => "keep" }, stored_map)
  end

  def deploy_and_feed_map(fs)
    fields = <<~FIELDS
      field my_map type map<string, string> {
        indexing: summary
        #{fs}
      }
    FIELDS
    deploy_app(SearchApp.new.sd(write_sd(fields)))
    start
    feed_and_wait_for_docs("fast_map_search", 1, :file => selfdir+"feed_entry_update.json")
    assert_equal({ "foo" => "stale", "baz" => "keep" }, stored_map)
  end

  def stored_map
    vespa.document_api_v1.get("id:fast_map_search:fast_map_search::0").fields["my_map"]
  end

  def test_rejected_setups
    check_cased_key_only_deployment_fails
    check_cased_value_only_deployment_fails
    check_array_of_struct_without_key_and_value_deployment_fails
    check_array_of_struct_with_unknown_key_deployment_fails
  end

end
