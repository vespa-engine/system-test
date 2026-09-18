# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

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
    FIELDS

  def feed_and_wait
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::0")
                                      .add_field("my_map_string", { "foo" => "bar" })
                                      .add_field("my_map_int", { "foo" => 42 })
                                      .add_field("my_map_long", { "foo" => 4294967338 })
    )
    vespa.document_api_v1.put(Document.new("id:fast_map_search:fast_map_search::1")
                                      .add_field("my_map_string", { "foo" => "qux", "baz" => "bar" })
                                      .add_field("my_map_int", { "foo" => 13, "baz" => 42 })
                                      .add_field("my_map_long", { "foo" => 4294967309, "baz" => 4294967338 })
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
    assert(result.json.to_s.include?("#{field}$keyvalue"),
           "Expected sameElement to be rewritten to a fast map lookup")

    # The rewrite does not change the result: the map summary is returned,
    # and the synthetic attribute is not part of it.
    assert_result(public_send(make_query_fn, field, "foo", value_one), selfdir + result_file)
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
    fs = "map: fast-search"
    fields = <<~FIELDS
      field string_map type map<string, string> {
        indexing: summary
        #{fs}
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
      field cased_string_map type map<string, string> {
        indexing: summary
        #{fs}
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
        #{fs}
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
      field cased_int_map type map<string, int> {
        indexing: summary
        #{fs}
        struct-field key {
          indexing: attribute
          match: cased
        }
        struct-field value { indexing: attribute }
      }
      field long_map type map<string, long> {
        indexing: summary
        #{fs}
        struct-field key { indexing: attribute }
        struct-field value { indexing: attribute }
      }
      field cased_long_map type map<string, long> {
        indexing: summary
        #{fs}
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
    assert_hitcount({"yql" => "select * from sources * where string_map{\"case_does_not_matter\"} contains \"foo\""}, 1)
    assert_hitcount({"yql" => "select * from sources * where string_map{\"case_does_not_matter\"} contains \"FOO\""}, 1)
    assert_hitcount({"yql" => "select * from sources * where string_map{\"CASE_DOES_NOT_MATTER\"} contains \"foo\""}, 1)
    assert_hitcount({"yql" => "select * from sources * where string_map{\"CASE_DOES_NOT_MATTER\"} contains \"FOO\""}, 1)

    assert_hitcount({"yql" => "select * from sources * where int_map{\"case_does_not_matter\"} contains 42"}, 1)
    assert_hitcount({"yql" => "select * from sources * where int_map{\"CASE_DOES_NOT_MATTER\"} contains 42"}, 1)

    assert_hitcount({"yql" => "select * from sources * where long_map{\"case_does_not_matter\"} contains 4294967338"}, 1)
    assert_hitcount({"yql" => "select * from sources * where long_map{\"CASE_DOES_NOT_MATTER\"} contains 4294967338"}, 1)

    puts "Cased matching"
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"case_matters\"} contains \"foo\""}, 1)
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"case_matters\"} contains \"FOO\""}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"case_matters\"} contains \"bar\""}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"case_matters\"} contains \"BAR\""}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"CASE_MATTERS\"} contains \"foo\""}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"CASE_MATTERS\"} contains \"FOO\""}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"CASE_MATTERS\"} contains \"bar\""}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_string_map{\"CASE_MATTERS\"} contains \"BAR\""}, 1)

    assert_hitcount({"yql" => "select * from sources * where cased_int_map{\"case_matters\"} contains 42"}, 1)
    assert_hitcount({"yql" => "select * from sources * where cased_int_map{\"case_matters\"} contains 43"}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_int_map{\"CASE_MATTERS\"} contains 42"}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_int_map{\"CASE_MATTERS\"} contains 43"}, 1)

    assert_hitcount({"yql" => "select * from sources * where cased_long_map{\"case_matters\"} contains 4294967338"}, 1)
    assert_hitcount({"yql" => "select * from sources * where cased_long_map{\"case_matters\"} contains 4294967339"}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_long_map{\"CASE_MATTERS\"} contains 4294967338"}, 0)
    assert_hitcount({"yql" => "select * from sources * where cased_long_map{\"CASE_MATTERS\"} contains 4294967339"}, 1)
  end

  def test_cased_key_only_deployment_fails
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

  def test_cased_value_only_deployment_fails
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
    assert(result.json.to_s.include?("#{field}$keyvalue"),
           "Expected map range to be rewritten to a fast map lookup")

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

  def verify_ids(expected_ids, result)
    expected_ids_array = Array(expected_ids)
    got_ids_array = result.hit.map{ |hit| hit.field["id"] }
    assert_equal(expected_ids_array, got_ids_array)
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

end
