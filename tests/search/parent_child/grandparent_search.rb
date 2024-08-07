# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class GrandparentSearchTest < IndexedOnlySearchTest

  def setup
    set_owner("toregge")
    @test_dir = selfdir + "grandparent_search/"
  end

  def hit_count_query_string(doctype)
    "/search/?query=sddocname:#{doctype}&nocache&hits=0&ranking=unranked&model.restrict=#{doctype}"
  end

  def test_grandparent_search
    set_description("Test search in field imported from grandparent")
    deploy_app(SearchApp.new.sd(@test_dir + "grandparent.sd", { :global => true }).
               sd(@test_dir + "parent.sd", { :global => true }).
               sd(@test_dir + "child.sd"))

    start
    feedfile(@test_dir + "feed-0.json", :timeout => 240)
    assert_hitcount(hit_count_query_string("grandparent"), 2)
    assert_hitcount(hit_count_query_string("parent"), 4)
    assert_hitcount(hit_count_query_string("child"), 6)
    assert_fields("grandparent", "a1", [ 5, 6])
    assert_fields("parent", "a2", [10, 11, 12, 13])
    assert_fields("child", "a3", [100, 101, 102, 103, 104, 105])
    assert_fields("parent", "a1", [5, 6, nil, 5])
    assert_fields("child", "a1", [5, 6, nil, 5, 5, 6])
    assert_fields("child", "a2", [10, 11, 12, 13, 10, 11])
    assert_grandparent_search("a1:5", [100, 103, 104])
    assert_grandparent_search("a1:6", [101, 105])
    assert_grandparent_search("a1:7", [])
    feedfile(@test_dir + "feed-1.json", :timeout => 240)
    assert_fields("grandparent", "a1", [ 5, 6, 7])
    assert_fields("parent", "a2", [11, 12, 13])
    assert_fields("child", "a3", [100, 101, 102, 103, 104, 105])
    assert_fields("parent", "a1", [6, 7, 6])
    assert_fields("child", "a1", [nil, 6, 7, 6, nil, 6])
    assert_fields("child", "a2", [nil, 11, 12, 13, nil, 11])
    assert_grandparent_search("a1:5", [])
    assert_grandparent_search("a1:6", [101, 103, 105])
    assert_grandparent_search("a1:7", [102])
  end

  def assert_grandparent_search(query, exp_values)
    result = search("query=" + query + "&presentation.format=json&ranking=unranked&summary=mysummary&model.restrict=child")
    assert_field_values(result, "a3", exp_values)
  end

  def assert_fields(doc_type, field_name, exp_values)
    result = search("query=sddocname:#{doc_type}&presentation.format=json&ranking=unranked&summary=mysummary&model.restrict=#{doc_type}")
    assert_field_values(result, field_name, exp_values)
  end

  def assert_field_values(result, field_name, exp_values)
    result.sort_results_by("documentid")
    assert_equal(exp_values.size, result.hitcount)
    for i in 0...exp_values.size do
      exp_value = exp_values[i]
      act_value = result.hit[i].field[field_name]
      puts "#{i}: '#{exp_value}' == '#{act_value}' ?"
      assert_equal(exp_value, act_value)
    end
  end

  def teardown
    stop
  end

end
