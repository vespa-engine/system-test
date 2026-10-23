# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class MatchesFeature < IndexedStreamingSearchTest

  def setup
    set_owner("hmusum")
  end

  def test_matches
    set_description("Test the matches feature")
    deploy_app(SearchApp.new.sd(selfdir + 'matches.sd'))
    start
    feed_and_wait_for_docs("matches", 1, :file => selfdir + "matches.json")

    verify_matches
    verify_matchcount
    verify_matches_for_labels
  end

  def verify_matches
    assert_matches({"matches(f1)" => 1}, "query=a")
    assert_matches({"matches(f1)" => 1}, "query=b")
    assert_matches({"matches(f1)" => 0}, "query=c")
    assert_matches({"matches(f1)" => 1}, "query=\"a b\"")
    assert_matches({"matches(f1,0)" => 1, "matches(f1,1)" => 0}, "query=b+c")

    assert_matches({"matches(f2)" => 0}, "query=a")
    assert_matches({"matches(f2)" => 1}, "query=b")
    assert_matches({"matches(f2)" => 1}, "query=c")
    assert_matches({"matches(f2)" => 1}, "query=\"b c\"")
    assert_matches({"matches(f2,0)" => 0, "matches(f2,1)" => 1}, "query=a+b")

    assert_matches({"matches(f3)" => 0}, "query=a")
    assert_matches({"matches(f3)" => 1}, "query=f3:a")
    assert_matches({"matches(f3,0)" => 0, "matches(f3,1)" => 1}, "query=a+f3:a")

    assert_matches({"matches(f4)" => 0}, "query=a")
    assert_matches({"matches(f4)" => 1}, "query=f4:a")
    assert_matches({"matches(f4)" => 1}, "query=f4:d")
    assert_matches({"matches(f4)" => 0}, "query=a+f4:c")
    assert_matches({"matches(f4,0)" => 0, "matches(f4,1)" => 1}, "query=a+f4:a")

    assert_matches({"matches(f5.key)" => 0}, "query=a")
    assert_matches({"matches(f5.key)" => 1}, "query=f5.key:a")
    assert_matches({"matches(f5.key)" => 1}, "query=f5.key:d")
    assert_matches({"matches(f5.key)" => 0}, "query=a+f5.key:c")
    assert_matches({"matches(f5.key,0)" => 0, "matches(f5.key,1)" => 1}, "query=a+f5.key:a")

    assert_matches({"matches(f5.value)" => 0}, "query=a")
    assert_matches({"matches(f5.value)" => 1}, "query=f5.value:10")
    assert_matches({"matches(f5.value)" => 1}, "query=f5.value:40")
    assert_matches({"matches(f5.value)" => 0}, "query=a+f5.value:30")
    assert_matches({"matches(f5.value,0)" => 0, "matches(f5.value,1)" => 1}, "query=a+f5.value:10")

    assert_matches({"matches(f1)" => 1, "matches(f2)" => 0, "matches(f3)" => 0}, yql_query("f1 contains 'a' OR (f2 contains 'b' and !(f3 contains 'a'))"))
    same_elem_d = "sameElement(key contains 'd', value >= 40)"
    same_elem_a = "sameElement(key contains 'a', value >= 40)"
    assert_matches({"matches(f5)" => 1}, yql_query("f5 contains #{same_elem_d}"))
    assert_matches({"matches(f5)" => 1}, yql_query("f1 contains 'a' OR f5 contains #{same_elem_d}"))
    assert_matches({"matches(f5)" => 0}, yql_query("f1 contains 'a' OR f5 contains #{same_elem_a}"))
    assert_matches({"matches(f5,0)" => 0, "matches(f5,1)" => 1}, yql_query("f1 contains 'a' OR f5 contains #{same_elem_d}"))
  end

  def yql_query(where)
    URI.encode_www_form([["yql", "select * from sources * where #{where}"]])
  end

  def verify_matchcount
    assert_matches({"matchCount(f1)" => 1}, "query=a")
    assert_matches({"matchCount(f1)" => 1}, "query=b")
    assert_matches({"matchCount(f1)" => 0}, "query=c")
    assert_matches({"matchCount(f1)" => 1}, "query=d")
    assert_matches({"matchCount(f1)" => 1}, "query=(a+x)")
    assert_matches({"matchCount(f1)" => 2}, "query=a+d")
    assert_matches({"matchCount(f1)" => 2}, "query=a d")
    assert_matches({"matchCount(f1)" => 1}, "query=\"a b\"")
    assert_matches({"matchCount(f1)" => 3}, "query=(a+d+b)")
    assert_matches({"matchCount(f1)" => 3}, "query=a b d")
  end

  def verify_matches_for_labels
    # No labels in the query
    assert_matches_for_labels(yql_query("f1 contains 'a'"))
    # A label gets a cell only for the field its term searches, and in the field-less variant
    assert_matches_for_labels(yql_query("f1 contains ({label:'x'}'a')"), f1: {'x' => 1}, any: {'x' => 1})
    assert_matches_for_labels(yql_query("f2 contains ({label:'x'}'b')"), f2: {'x' => 1}, any: {'x' => 1})
    assert_matches_for_labels(yql_query("f3 contains ({label:'x'}'a')"), f3: {'x' => 1}, any: {'x' => 1})
    # A label whose term did not match gets no cell
    assert_matches_for_labels(yql_query("f1 contains ({label:'x'}'a') or f1 contains ({label:'y'}'c')"),
                              f1: {'x' => 1}, any: {'x' => 1})
    # A label carried by several query items matches if any of them matched
    assert_matches_for_labels(yql_query("f1 contains ({label:'x'}'c') or f3 contains ({label:'x'}'a')"),
                              f3: {'x' => 1}, any: {'x' => 1})
    assert_matches_for_labels(yql_query("f1 contains ({label:'x'}'a') or f1 contains ({label:'x'}'c')"),
                              f1: {'x' => 1}, any: {'x' => 1})
    # Each matching label gets one cell with value 1, however many of its items matched
    assert_matches_for_labels(yql_query("f1 contains ({label:'x'}'a') or f1 contains ({label:'x'}'b') or f1 contains ({label:'y'}'d')"),
                              f1: {'x' => 1, 'y' => 1}, any: {'x' => 1, 'y' => 1})
    # Labeled phrases
    assert_matches_for_labels(yql_query("f1 contains ({label:'p'}phrase('a', 'b')) or f1 contains ({label:'q'}phrase('b', 'a'))"),
                              f1: {'p' => 1}, any: {'p' => 1})
    # The labeled operator searches no field of its own, so only the field-less variant sees it
    assert_matches_for_labels(yql_query("rank(f1 contains 'a', labeled(f1 contains 'd', 'w', 1.0))"), any: {'w' => 1})
    assert_matches_for_labels(yql_query("rank(f1 contains 'a', labeled(f1 contains 'c', 'w', 1.0))"))
  end

  def assert_matches_for_labels(query, f1: {}, f2: {}, f3: {}, any: {})
    sf = search(query).hit[0].field['summaryfeatures']
    type = 'tensor<float>(label{})'
    assert_mapped_tensor_feature(f1, sf, 'matches_for_labels(f1)', type)
    assert_mapped_tensor_feature(f2, sf, 'matches_for_labels(f2)', type)
    assert_mapped_tensor_feature(f3, sf, 'matches_for_labels(f3)', type)
    assert_mapped_tensor_feature(any, sf, 'matches_for_labels', type)
  end

  def assert_matches(expected, query)
    result = search(query)
    assert_features(expected, result.hit[0].field['summaryfeatures'], 1e-4)
  end


end
