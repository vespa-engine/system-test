# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance/tensor_eval/tensor_eval'

class TensorEvalExpensivePerfTest < TensorEvalPerfTest

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_evaluation_expensive
    set_description("Test performance of various expensive tensor evaluation use cases")
    @graphs = get_graphs_expensive
    deploy_and_feed(5000)

    [5,10,25].each do |wset_entries|
      run_fbench_helper(MATCH, TENSOR_MATCH_25X25, wset_entries, "queries.tensor.sparse.y.#{wset_entries}.txt")
    end

    [5,10,25,50].each do |wset_entries|
      run_fbench_helper(MATCH, TENSOR_MATCH_50X50, wset_entries, "queries.tensor.sparse.y.#{wset_entries}.txt")
    end

    [5,10,25,50,100].each do |wset_entries|
      run_fbench_helper(MATCH, TENSOR_MATCH_100X100, wset_entries, "queries.tensor.sparse.y.#{wset_entries}.txt")
    end

    [10,50,100].each do |entries|
      run_fbench_helper(SPARSE_MULTIPLY, SPARSE_MULTIPLY_NO_OVERLAP, entries, "queries.tensor.sparse.y.#{entries}.txt")
    end

    [5,10,50].each do |entries|
      run_fbench_helper(SPARSE_MULTIPLY, SPARSE_MULTIPLY_PARTIAL_OVERLAP, entries, "queries.tensor.sparse.yz.#{entries}.txt")
    end

    [10,25,50,100].each do |wset_entries|
      rank_profile = "tensor_matrix_product_#{wset_entries}x#{wset_entries}"
      query_file = "queries.tensor.dense.#{wset_entries}.txt"
      run_fbench_helper(MATRIX_PRODUCT, rank_profile, wset_entries, query_file)
    end
  end

  def get_graphs_expensive
    [
      get_latency_graphs_for_rank_profile(TENSOR_MATCH_25X25),
      get_latency_graphs_for_rank_profile(TENSOR_MATCH_50X50),
      get_latency_graphs_for_rank_profile(TENSOR_MATCH_100X100),
      get_latency_graphs_for_rank_profile(SPARSE_MULTIPLY_NO_OVERLAP),
      get_latency_graphs_for_rank_profile(SPARSE_MULTIPLY_PARTIAL_OVERLAP),
      get_latency_graphs_for_eval_type(MATRIX_PRODUCT),
      get_latency_graph_for_rank_profile(TENSOR_MATCH_50X50,            50, 380, 450),
      get_latency_graph_for_rank_profile(SPARSE_MULTIPLY_NO_OVERLAP, 50, 125, 145),
      get_latency_graph_for_rank_profile(SPARSE_MULTIPLY_PARTIAL_OVERLAP, 10, 200, 230),
      get_latency_graph_for_rank_profile("tensor_matrix_product_25x25", 25, 1.70, 2.20)
    ]
  end

  def teardown
    super
  end

end
