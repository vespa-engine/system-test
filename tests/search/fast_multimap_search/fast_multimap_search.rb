# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

# 'map: fast-search' is only available for the map type. This test demonstrates that the same
# principle works for a multimap, an array of key-value structs in which a key can occur more
# than once: The schema builds the synthetic key-value attribute with an indexing script, and
# FastMultimapSearcher, adapted from the FastMapSearcher of Vespa, rewrites sameElement queries
# to lookups in it.
class FastMultimapSearch < IndexedOnlySearchTest

  def setup
    set_description("Tests fast search in multimaps, with a synthetic key-value attribute and a custom searcher")
    set_owner("boeker")
  end

  def teardown
    stop
  end

  def deploy_and_feed
    add_bundle(selfdir + "FastMultimapSearcher.java")
    search_chain = SearchChain.new.add(Searcher.new("com.yahoo.test.FastMultimapSearcher"))
    deploy_app(SearchApp.new.sd(selfdir + "fast_multimap_search.sd").search_chain(search_chain))
    start

    # The key 'foo' occurs twice in document 0, which makes these multimaps rather than maps.
    # Every value occurs in both documents, but under different keys.
    vespa.document_api_v1.put(Document.new("id:fast_multimap_search:fast_multimap_search::0")
                                .add_field("id", 0)
                                .add_field("string_multimap", pairs("string_string_pair", [["foo", "red"], ["foo", "green"], ["bar", "blue"]]))
                                .add_field("int_multimap", pairs("string_int_pair", [["foo", 42], ["foo", -7], ["bar", 13]]))
                                .add_field("float_multimap", pairs("string_float_pair", [["foo", 1.5], ["foo", -0.5], ["bar", 0.25]])))
    vespa.document_api_v1.put(Document.new("id:fast_multimap_search:fast_multimap_search::1")
                                .add_field("id", 1)
                                .add_field("string_multimap", pairs("string_string_pair", [["foo", "blue"], ["baz", "red"], ["baz", "yellow"]]))
                                .add_field("int_multimap", pairs("string_int_pair", [["foo", 13], ["baz", 42], ["baz", 100]]))
                                .add_field("float_multimap", pairs("string_float_pair", [["foo", 0.25], ["baz", 1.5], ["baz", 10.0]])))
    wait_for_hitcount('query=sddocname:fast_multimap_search', 2)
  end

  def pairs(struct, key_values)
    key_values.map { |key, value| { "#{struct}_key" => key, "#{struct}_value" => value } }
  end

  ######################################################################################################################
  # Search tests
  ######################################################################################################################

  def test_search_basic
    deploy_and_feed

    # The key 'foo' has two values in document 0, and either of them matches.
    verify_query([0], contains_query("string_multimap", "foo", "red"))
    verify_query([0], contains_query("string_multimap", "foo", "green"))
    verify_query([1], contains_query("string_multimap", "foo", "blue"))
    verify_query([0], contains_query("string_multimap", "bar", "blue"))
    verify_query([1], contains_query("string_multimap", "baz", "yellow"))
    # A key-value pair matches only when both are in the same array element: document 1 holds
    # both the key 'foo' and the value 'yellow', and document 0 both 'bar' and 'red', but in
    # different elements.
    verify_query([], contains_query("string_multimap", "foo", "yellow"))
    verify_query([], contains_query("string_multimap", "bar", "red"))
    # Key and value are matched uncased, both by the synthetic attribute and by the struct-field attributes.
    verify_query([0], contains_query("string_multimap", "FOO", "Green"))

    # The same for int values.
    verify_query([0], equals_query("int_multimap", "foo", 42))
    verify_query([0], equals_query("int_multimap", "foo", -7))
    verify_query([1], equals_query("int_multimap", "foo", 13))
    verify_query([0], equals_query("int_multimap", "bar", 13))
    verify_query([1], equals_query("int_multimap", "baz", 100))
    verify_query([], equals_query("int_multimap", "foo", 100))
    verify_query([], equals_query("int_multimap", "bar", 42))
    # A quoted value is rewritten too.
    verify_query([0], contains_query("int_multimap", "foo", "-7"))
    verify_query([], contains_query("int_multimap", "foo", "100"))

    # The same for float values.
    verify_query([0], equals_query("float_multimap", "foo", 1.5))
    verify_query([0], equals_query("float_multimap", "foo", -0.5))
    verify_query([1], equals_query("float_multimap", "foo", 0.25))
    verify_query([0], equals_query("float_multimap", "bar", 0.25))
    verify_query([1], equals_query("float_multimap", "baz", 10.0))
    verify_query([], equals_query("float_multimap", "foo", 10.0))
    verify_query([], equals_query("float_multimap", "bar", 1.5))
    # A quoted value is rewritten too.
    verify_query([0], contains_query("float_multimap", "foo", "-0.5"))
    verify_query([], contains_query("float_multimap", "foo", "10.0"))
  end

  ######################################################################################################################
  # Range search
  ######################################################################################################################

  # Numeric multimaps only: like FastMapSearcher, FastMultimapSearcher does not rewrite a string range.
  def test_range_basic
    deploy_and_feed

    # The key 'foo' has two values in document 0, and a range around either of them matches.
    verify_query([0], range_query("int_multimap", "foo", 40, 45))
    verify_query([0], range_query("int_multimap", "foo", -10, -5))
    verify_query([1], range_query("int_multimap", "foo", 12, 14))
    verify_query([1], range_query("int_multimap", "baz", 90, 110))
    # Only the elements with the queried key are considered.
    verify_query([], range_query("int_multimap", "foo", 90, 110))
    verify_query([], range_query("int_multimap", "bar", 40, 45))
    # Document 0 has -7 and 42 as the values of 'foo', and document 1 has 13, which lies between them.
    verify_query([0, 1], range_query("int_multimap", "foo", -7, 42))
    verify_query([0, 1], range_query("int_multimap", "foo", -7, 42, "leftOpen"))
    verify_query([0, 1], range_query("int_multimap", "foo", -7, 42, "rightOpen"))
    verify_query([1], range_query("int_multimap", "foo", -7, 42, "open"))
    # Unbounded ranges do not reach into the elements of other keys.
    verify_query([0], range_query("int_multimap", "foo", "-Infinity", -7))
    verify_query([0, 1], range_query("int_multimap", "foo", "-Infinity", "Infinity"))
    verify_query([1], range_query("int_multimap", "baz", 13, "Infinity"))
    verify_query([], range_query("int_multimap", "bar", 13, "Infinity", "leftOpen"))

    # The same for float values, where the ranges also cross zero.
    verify_query([0], range_query("float_multimap", "foo", 1.0, 2.0))
    verify_query([0], range_query("float_multimap", "foo", -1.0, -0.25))
    verify_query([1], range_query("float_multimap", "foo", 0.0, 0.5))
    verify_query([1], range_query("float_multimap", "baz", 5.0, 20.0))
    verify_query([], range_query("float_multimap", "foo", 5.0, 20.0))
    verify_query([], range_query("float_multimap", "bar", 1.0, 2.0))
    verify_query([0, 1], range_query("float_multimap", "foo", -0.5, 1.5))
    verify_query([0, 1], range_query("float_multimap", "foo", -0.5, 1.5, "leftOpen"))
    verify_query([0, 1], range_query("float_multimap", "foo", -0.5, 1.5, "rightOpen"))
    verify_query([1], range_query("float_multimap", "foo", -0.5, 1.5, "open"))
    verify_query([0], range_query("float_multimap", "foo", "-Infinity", -0.5))
    verify_query([0, 1], range_query("float_multimap", "foo", "-Infinity", "Infinity"))
    verify_query([1], range_query("float_multimap", "baz", 0.25, "Infinity"))
    verify_query([], range_query("float_multimap", "bar", 0.25, "Infinity", "leftOpen"))
  end

  ######################################################################################################################
  # Helpers
  ######################################################################################################################

  # The struct holding the key-value pairs of each multimap.
  STRUCTS = {
    "string_multimap" => "string_string_pair",
    "int_multimap" => "string_int_pair",
    "float_multimap" => "string_float_pair"
  }

  # Matches the documents with an element in which the key is the given key and the value contains the given value.
  def contains_query(field, key, value)
    struct = STRUCTS[field]
    "#{field} contains sameElement(#{struct}_key contains '#{key}', #{struct}_value contains '#{value}')"
  end

  # Matches the documents with an element in which the key is the given key and the value equals the given number.
  def equals_query(field, key, value)
    struct = STRUCTS[field]
    "#{field} contains sameElement(#{struct}_key contains '#{key}', #{struct}_value = #{value})"
  end

  # Matches the documents with an element in which the key is the given key and the value is in the given range.
  # Both ends are included, unless bounds is given as "leftOpen", "rightOpen" or "open".
  def range_query(field, key, from, to, bounds = nil)
    struct = STRUCTS[field]
    annotation = bounds.nil? ? "" : "{bounds:\"#{bounds}\"}"
    "#{field} contains sameElement(#{struct}_key contains '#{key}', (#{annotation}range(#{struct}_value, #{from}, #{to})))"
  end

  # Runs the query with the rewrite, verifying through the query trace that it happened, and
  # with the regular sameElement, verifying that both match the expected documents.
  def verify_query(expected_ids, where)
    yql = "select * from sources * where #{where} order by id asc"

    result = search({"yql" => yql, "tracelevel" => "2"})
    field = where.split.first
    assert(result.json.to_s.include?("#{field}_keyvalue"),
           "Expected '#{where}' to be rewritten to a fast multimap lookup")
    verify_ids(expected_ids, result)

    verify_ids(expected_ids, search({"yql" => yql, "fastmultimap.disable" => "true"}))
  end

  def verify_ids(expected_ids, result)
    got_ids = result.hit.map { |hit| hit.field["id"] }
    assert_equal(expected_ids, got_ids)
  end

end
