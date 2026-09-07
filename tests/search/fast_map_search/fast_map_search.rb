# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class FastMapSearch < IndexedOnlySearchTest

  def setup
    set_description("Tests fast map search feature")
    set_owner("johsol")
  end

  def test_fast_map_search_basic_string
    deploy_app(SearchApp.new.sd(write_sd("map: fast-search", "string")))
    start
    feed_and_wait_for_docs("fast_map_search", 2, :file => selfdir+"feed.json")

    run_queries(:same_element_query, "bar", "baz", "result.json")
    run_queries(:shortform_query, "bar", "baz", "result.json")
  end

  def test_fast_map_search_basic_int
    deploy_app(SearchApp.new.sd(write_sd("map: fast-search", "int")))
    start
    feed_and_wait_for_docs("fast_map_search", 2, :file => selfdir+"feed_int.json")

    run_queries(:same_element_query, 42, 43, "result_int.json")
    run_queries(:shortform_query, 42, 43, "result_int.json")
    run_queries(:shortform_equals_query, 42, 43, "result_int.json")
  end

  def test_fast_map_search_range_int
    # A range inside sameElement matches the 'value' struct-field attribute, which
    # 'map: fast-search' does not create on its own: it only adds the synthetic
    # key-value attribute. Declare the key and value attributes so the sameElement
    # form has something to match and can serve as a reference for the fancy syntax.
    field_body = <<~BODY
      map: fast-search
      struct-field key { indexing: attribute }
      struct-field value { indexing: attribute }
    BODY
    deploy_app(SearchApp.new.sd(write_sd(field_body, "int")))
    start
    feed_and_wait_for_docs("fast_map_search", 2, :file => selfdir+"feed_int.json")

    run_range_queries(:same_element_range_query)
    run_range_queries(:map_range_query)
  end


  def run_queries(make_query_fn, value_one, value_two, result_file)
    # A key-value pair matches only when both are present in the same map entry.
    # Document 1 contains both the key 'foo' and the value 'bar', but in different
    # entries, so it must not match.
    assert_hitcount(public_send(make_query_fn, "foo", value_one), 1)
    assert_hitcount(public_send(make_query_fn, "baz", value_one), 1)
    assert_hitcount(public_send(make_query_fn, "foo", value_two), 0)

    # 'map: fast-search' makes the container rewrite the sameElement operator to a
    # single lookup in the synthetic key-value attribute. Verify through the query
    # trace that the rewrite actually happened.
    result = search(public_send(make_query_fn, "foo", value_one, 2))
    assert(result.json.to_s.include?("my_map$keyvalue"),
           "Expected sameElement to be rewritten to a fast map lookup")

    # The rewrite does not change the result: the map summary is returned,
    # and the synthetic attribute is not part of it.
    assert_result(public_send(make_query_fn, "foo", value_one), selfdir + result_file)
  end

  def run_range_queries(make_query_fn)
    # Only the entry with the queried key is considered: document 0 has foo=42 while
    # document 1 has foo=13, so a range around 42 on key 'foo' matches document 0 only.
    assert_hitcount(public_send(make_query_fn, "foo", 40, 50), 1)
    assert_hitcount(public_send(make_query_fn, "foo", 10, 20), 1)
    assert_hitcount(public_send(make_query_fn, "baz", 40, 50), 1)

    # Document 1 is the only one with the key 'baz', and its value 42 is outside the range.
    assert_hitcount(public_send(make_query_fn, "baz", 10, 20), 0)

    # 'map: fast-search' makes the container rewrite the range to a lexical range over the
    # synthetic key-value attribute. Verify through the query trace that it happened.
    result = search(public_send(make_query_fn, "foo", 40, 50, 2))
    assert(result.json.to_s.include?("my_map$keyvalue"),
           "Expected map range to be rewritten to a fast map lookup")

    # The rewrite does not change the result: the map summary is returned,
    # and the synthetic attribute is not part of it.
    assert_result(public_send(make_query_fn, "foo", 40, 50), selfdir + "result_int.json")
  end

  def same_element_query(key, value, tracelevel = nil)
    yql = "select * from sources * where my_map contains sameElement(" +
          "key contains '#{key}', value contains '#{value}')"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  # fancy syntax: field{key} contains value.
  def shortform_query(key, value, tracelevel = nil)
    yql = "select * from sources * where my_map{'#{key}'} contains '#{value}'"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  # fancy syntax: field{key} = value. Unquoted, so the value stays a numeric term
  # rather than the word term the quoted 'contains' spelling produces.
  def shortform_equals_query(key, value, tracelevel = nil)
    yql = "select * from sources * where my_map{'#{key}'} = #{value}"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  def same_element_range_query(key, from, to, tracelevel = nil)
    yql = "select * from sources * where my_map contains sameElement(" +
          "key contains '#{key}', range(value, #{from}, #{to}))"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  # fancy syntax: range(field{key}, from, to).
  def map_range_query(key, from, to, tracelevel = nil)
    yql = "select * from sources * where range(my_map{'#{key}'}, #{from}, #{to})"
    form = [['yql', yql]]
    form << ['tracelevel', tracelevel.to_s] if tracelevel
    URI.encode_www_form(form)
  end

  def write_sd(field_body, type)
    sd_file = "#{dirs.tmpdir}fast_map_search.sd"
    File.write(sd_file, <<~SD)
      schema fast_map_search {
        document fast_map_search {
          field my_map type map<string, #{type}> {
            indexing: summary
            #{field_body}
          }
        }
      }
    SD
    sd_file
  end

  def teardown
    stop
  end

end
