# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class LexicalRangeSearch < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
    set_description("Test lexi(cographi)cal range search")
    @to = 15
    @range = 1..@to
  end

  def to_hex(n)
    "h%04X" % n
  end

  def feed_docs
    @range.each do |n|
      hex_string = to_hex(n)
      hex_strings = [to_hex(n)]
      vespa.document_api_v1.put(Document.new("id:test:test::#{n}")
                                        .add_field("id", n)
                                        .add_field("string_single", hex_string)
                                        .add_field("string_single_fast", hex_string)
                                        .add_field("string_multi", hex_strings)
                                        .add_field("string_multi_fast", hex_strings))
    end
    wait_for_hitcount('query=sddocname:test', @range.size)
  end

  def test_lexical_range
    deploy_app(SearchApp.new.cluster_name("test").sd(selfdir+"test.sd"))
    start

    feed_docs
    verify_range("string_single")
    verify_range("string_single_fast")
    verify_range("string_multi")
    verify_range("string_multi_fast")
  end

  def get_query(annotation, field_name, from, to)
    from_str = from.nil? ? "-Infinity" : "\"#{to_hex(from)}\""
    to_str = to.nil? ? "Infinity" : "\"#{to_hex(to)}\""
    {"yql" => "select * from sources * where (#{annotation}range(#{field_name}, #{from_str}, #{to_str})) order by id asc", "hits" => @range.size}
  end

  def search_and_verify(expected_ids, query)
    result = search(query)
    verify_ids(expected_ids, result)
  end

  def verify_range(field_name)
    # Unbounded ranges
    @range.each do |mid|
      search_and_verify(1..mid, get_query("", field_name, nil, mid))
      search_and_verify(mid..@to, get_query("", field_name, mid, nil))
    end

    # Bounded ranges
    @range.each do |from|
      @range.each do |to|
        search_and_verify(from..to, get_query("", field_name, from, to))
        search_and_verify((from+1)..to, get_query("{bounds:\"leftOpen\"}", field_name, from, to))
        search_and_verify(from..(to-1), get_query("{bounds:\"rightOpen\"}", field_name, from, to))
        search_and_verify((from+1)..(to-1), get_query("{bounds:\"open\"}", field_name, from, to))
      end
    end
  end

  def verify_ids(expected_ids, result)
    expected_ids_array = Array(expected_ids)
    got_ids_array = result.hit.map{ |hit| hit.field["id"] }
    assert_equal(expected_ids_array, got_ids_array)
  end

end
