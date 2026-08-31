# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class FastMapSearch < IndexedOnlySearchTest

  def setup
    set_description("Tests fast map search feature")
    set_owner("johsol")
  end

  def test_fast_map_search_basic
    deploy_app(SearchApp.new.sd(write_sd("map: fast-search")))
    start
    feed_and_wait_for_docs("fast_map_search", 2, :file => selfdir+"feed.json")

    run_queries(:same_element_query)
    run_queries(:shortform_query)
  end

  def run_queries(make_query_fn)
    # A key-value pair matches only when both are present in the same map entry.
    # Document 1 contains both the key 'foo' and the value 'bar', but in different
    # entries, so it must not match.
    assert_hitcount(public_send(make_query_fn, "foo", "bar"), 1)
    assert_hitcount(public_send(make_query_fn, "baz", "bar"), 1)
    assert_hitcount(public_send(make_query_fn, "foo", "baz"), 0)

    # 'map: fast-search' makes the container rewrite the sameElement operator to a
    # single lookup in the synthetic key-value attribute. Verify through the query
    # trace that the rewrite actually happened.
    result = search(public_send(make_query_fn, "foo", "bar", 2))
    assert(result.json.to_s.include?("my_map$keyvalue"),
           "Expected sameElement to be rewritten to a fast map lookup")

    # The rewrite does not change the result: the map summary is returned,
    # and the synthetic attribute is not part of it.
    assert_result(public_send(make_query_fn, "foo", "bar"), selfdir + "result.json")
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

  def write_sd(field_body)
    sd_file = "#{dirs.tmpdir}fast_map_search.sd"
    File.write(sd_file, <<~SD)
      schema fast_map_search {
        document fast_map_search {
          field my_map type map<string, string> {
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
