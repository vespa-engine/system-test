# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class GlobalPhaseRanking < IndexedSearchTest

  DOCS = 5

  def setup
    set_owner("bjorncs")
    set_description("Test 'global-phase' ranking")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"),
               :files => {selfdir + "files/multiply_add.onnx" => "files/multiply_add.onnx",
                          selfdir + "files/matrix.json" => "files/matrix.json"})
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.json")
  end

  def test_global_phase
    puts "Search with second-phase ranking"
    result_sp = search("?input.query(query_vec)=[2.0,2.0]&query=sddocname:test&ranking=second_phase")
    puts "Search with global-phase ranking"
    result_gp = search("?input.query(query_vec)=[2.0,2.0]&query=sddocname:test&ranking=global_phase")
    puts "Hits second-phase ranking: #{result_sp}"
    puts "Hits global-phase ranking: #{result_gp}"

    assert_equal(DOCS, result_sp.hitcount)
    assert_equal(DOCS, result_gp.hitcount)

    fields_to_compare = ["documentid", "relevancy"]
    result_sp.setcomparablefields(fields_to_compare)
    result_gp.setcomparablefields(fields_to_compare)

    result_sp.hit.each_index do |i|
      result_sp.hit[i].check_equal(result_gp.hit[i])
    end

    puts "Search with global-phase ranking expression using 'firstPhase'"
    query = "?input.query(query_vec)=[2.0,2.0]&query=sddocname:test&ranking=global_phase_inverse_first_phase&summary=minimal"
    assert_result(query, selfdir + "answers/first-phase-as-rank-feature.json", nil, fields_to_compare)

    puts "Verify global-phase with sorting is preemptively failed"
    query = "?input.query(query_vec)=[2.0,2.0]&query=sddocname:test&ranking=global_phase&sorting=-score"
    assert_query_errors(query, ['Sorting is not supported with global phase'])
  end

  def teardown
    stop
  end
end