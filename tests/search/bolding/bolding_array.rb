# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class BoldingArrayTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_bolding_array
    set_description("Test bolding support on array of string fields")
    deploy_app(SearchApp.new.sd(selfdir + "bolding_array/test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "bolding_array/docs.json")

    run_test_case("\"bolding\"", bolding_result)
    run_test_case("\"matching\"", matching_result)
    if is_streaming
      run_test_case("({substring:true}\"oldin\")", oldin_substring_result)
    end
  end

  def bolding_result
    ["<hi>Bolding</hi> highlights matching query terms in the summary.",
     "Set <hi>bolding</hi> on to enable it."]
  end

  def matching_result
    ["Bolding highlights <hi>matching</hi> query terms in the summary.",
     "Set bolding on to enable it."]
  end

  def oldin_substring_result
    ["B<hi>oldin</hi>g highlights matching query terms in the summary.",
     "Set b<hi>oldin</hi>g on to enable it."]
  end

  def run_test_case(query_term, exp_result)
    assert_teaser_field("content_1", query_term, "content_1", "default", exp_result)
    assert_teaser_field("content_2", query_term, "content_2_dyn", "my_sum", exp_result)
  end

  def assert_teaser_field(query_field, query_term, summary_field, summary, exp_result)
    form = [["yql", "select * from sources * where #{query_field} contains #{query_term}"],
            ["summary", summary ],
            ["streaming.selection", "true"]]
    query = URI.encode_www_form(form)
    result = search(query)
    assert_hitcount(result, 1)
    act_teaser = result.hit[0].field[summary_field]
    assert_equal(exp_result, act_teaser, "Unexpected result for field '#{summary_field}' using query '#{query_field}:#{query_term}'")
  end

  def teardown
    stop
  end

end
