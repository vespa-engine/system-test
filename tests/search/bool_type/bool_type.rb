# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'set'

class BoolTypeTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def self.final_test_methods
    ['test_imported_bool_attribute_search']
  end

  def test_bool_attribute_search
    set_description("Test search on attributes of type 'bool', and use in document selections, both with and without attribute backing")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").enable_document_api)
    @doctype = "test"
    start
    feed(:file => selfdir + "docs.json")

    run_search_test
    bool_fields_can_be_used_in_document_selections
  end

  def test_imported_bool_attribute_search
    @params = { :search_type => 'INDEXED' }
    set_description("Test search on imported attributes of type 'bool'")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd", { :global => true }).sd(selfdir + "child.sd"))
    @doctype = "child"
    start
    feed(:file => selfdir + "docs.json")
    feed(:file => selfdir + "docs_child.json")

    run_search_test
  end

  def bool_fields_can_be_used_in_document_selections
    # b1 and b2 are attributes, b3 is not
    assert_visit_matches([1, 3], 'test.b1 == true')
    assert_visit_matches([0, 2], 'test.b1 == false')
    assert_visit_matches([1],    'test.b1 == true and test.b2 == false')
    assert_visit_matches([1, 3], 'test.b3 == true')
    assert_visit_matches([0, 2], 'test.b3 != true')
    assert_visit_matches([2],    'test.b2 == true and test.b3 == false')
  end

  def run_search_test
    assert_hits([0, 2], "b1 = false")
    assert_hits([1, 3], "b1 = true")
    assert_hits([0, 1], "b2 = false")
    assert_hits([2, 3], "b2 = true")

    assert_hits([0], "b1 = false and b2 = false")
    assert_hits([1], "b1 = true and b2 = false")
    assert_hits([2], "b1 = false and b2 = true")
    assert_hits([3], "b1 = true and b2 = true")

    assert_hits([1], "!(b1 = false) and b2 = false")
    assert_hits([0], "!(b1 = true) and b2 = false")
    assert_hits([3], "!(b1 = false) and b2 = true")
    assert_hits([2], "!(b1 = true) and b2 = true")
    check_summary_features
  end

  def check_hit_summary_features(hit, exp_val)
    assert_features({'attribute(b1)' => exp_val}, hit.field['summaryfeatures'])
  end

  def check_summary_features
    result = search(get_query('b1 = true'))
    assert_hitcount(result, 2)
    check_hit_summary_features(result.hit[0], 1.0)
    check_hit_summary_features(result.hit[1], 1.0)
    result = search(get_query('b1 = false'))
    assert_hitcount(result, 2)
    check_hit_summary_features(result.hit[0], 0.0)
    check_hit_summary_features(result.hit[1], 0.0)
  end

  def assert_hits(exp_docids, expr)
    query = get_query(expr)
    puts "assert_hits(#{exp_docids}): query='#{query}'"
    result = search(query)
    result.sort_results_by("documentid")
    assert_hitcount(result, exp_docids.size)
    for i in 0...exp_docids.size
      docid = get_docid(exp_docids[i])
      assert_equal(docid, result.hit[i].field['documentid'])
    end
  end

  def get_query(expr)
    "yql=select %2a from sources %2a where " + expr + "&model.restrict=#{@doctype}"
  end

  def get_docid(id)
    "id:#{@doctype}:#{@doctype}::#{id}"
  end

  def doc_api_visit(selection:)
    # Use a high enough wanted doc count that everything is returned in one chunk without
    # the need for continuation tokens.
    result = vespa.document_api_v1.visit({:selection => selection,
                                          :cluster => 'search',
                                          :wantedDocumentCount => 100})
    result['documents'].map{|d| d['id'] }.to_set
  end

  def assert_visit_matches(exp_ids, selection)
    visited_ids = doc_api_visit(selection: selection)
    wanted_ids = exp_ids.map{|id| get_docid(id) }.to_set
    assert_equal(wanted_ids, visited_ids)
  end

  def teardown
    stop
  end

end
