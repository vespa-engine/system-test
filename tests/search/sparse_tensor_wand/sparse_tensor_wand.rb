# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SparseTensorWandTest < IndexedStreamingSearchTest

  QUERY_TENSOR = '{{x:a}:1.0,{x:b}:1.0,{x:c}:3.0}'

  # Dot product between QUERY_TENSOR and the tensor in each document (doc 6 has no tensor).
  SCORES = { 1 => 3.0, 2 => 3.0, 3 => 0.0, 4 => 4.0, 5 => 13.0, 6 => 0.0, 7 => -1.0, 8 => 3.0 }

  def setup
    set_owner("arnej")
  end

  def test_sparse_tensor_wand
    set_description("Test the sparseTensorWand query operator on sparse tensor attributes")
    # Single-threaded matching makes the heap threshold progression deterministic enough to assert on.
    # All documents are in the same group (n=1), and thus the same bucket, so that streaming search
    # scores them all in one search visitor with a single heap.
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").threads_per_search(1))
    start
    feed_and_wait_for_docs("test", 8, :file => selfdir + "docs.json")

    [ ["sv", "q"], ["sv_fast", "q"], ["svf", "qf"] ].each do |field, query_tensor|
      puts "Testing field #{field} with query(#{query_tensor})"
      assert_hits_above_threshold(field, query_tensor)
      assert_initial_score_threshold(field, query_tensor)
      assert_threshold_raised_by_heap(field, query_tensor)
    end
    assert_type_mismatch_is_rejected
  end

  def get_query(field, query_tensor, annotations = "")
    yql = "select * from sources * where {label:\"stw\"#{annotations}}sparseTensorWand(#{field}, #{query_tensor})"
    { 'yql' => yql,
      'ranking.features.query(q)' => QUERY_TENSOR,
      'ranking.features.query(qf)' => QUERY_TENSOR,
      'hits' => '20' }
  end

  # Returns the ids of the hits, and checks relevancy and summary features of each hit.
  def get_hit_ids(result, field)
    result.hit.map do |hit|
      id = hit.field['id'].to_i
      score = SCORES[id]
      assert_in_delta(score, hit.field['relevancy'].to_f, 1e-6, "relevancy of doc #{id}")
      features = hit.field['summaryfeatures']
      assert_in_delta(score, features['itemRawScore(stw)'].to_f, 1e-6, "itemRawScore(stw) of doc #{id}")
      assert_in_delta(score, features["dp_#{field}"].to_f, 1e-6, "dp_#{field} of doc #{id}")
      id
    end
  end

  def assert_hits_above_threshold(field, query_tensor)
    result = search(get_query(field, query_tensor, ",targetHits:100"))
    assert_equal(5, result.hit.size)
    ids = get_hit_ids(result, field)
    assert_equal([5, 4], ids[0, 2])
    assert_equal([1, 2, 8], ids[2, 3].sort)
  end

  def assert_initial_score_threshold(field, query_tensor)
    result = search(get_query(field, query_tensor, ",targetHits:100,scoreThreshold:3.5"))
    assert_equal([5, 4], get_hit_ids(result, field))

    # A negative threshold also gives hits for documents with no overlap. Documents with no
    # tensor at all have score 0 in indexed search, but never match in streaming search.
    result = search(get_query(field, query_tensor, ",targetHits:100,scoreThreshold:-2.0"))
    ids = get_hit_ids(result, field)
    assert_equal([5, 4], ids[0, 2])
    assert_equal([1, 2, 8], ids[2, 3].sort)
    if is_streaming
      assert_equal([3, 7], ids[5..])
    else
      assert_equal([3, 6], ids[5, 2].sort)
      assert_equal(7, ids[7])
    end
  end

  def assert_threshold_raised_by_heap(field, query_tensor)
    # With targetHits 2 the threshold is raised once two hits are found. The exact
    # set of hits depends on the order documents are matched, but the two best
    # documents are always hits, and at most two of the documents with score 3 are.
    result = search(get_query(field, query_tensor, ",targetHits:2"))
    ids = get_hit_ids(result, field)
    assert_equal([5, 4], ids[0, 2])
    assert(ids.size <= 4, "Expected at most 4 hits, got #{ids}")
    ids[2..].each { |id| assert_equal(3.0, SCORES[id]) }
  end

  def assert_type_mismatch_is_rejected
    # query(q) is tensor(x{}) while svf is tensor<float>(x{})
    assert_query_errors(get_query("svf", "q", ",targetHits:10"),
                        ["field type tensor<float>\\(x\\{\\}\\) does not match query type tensor\\(x\\{\\}\\)"])
  end

end
