# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance/tensor_eval/tensor_eval'

class TensorEvalNormalPerfTest < TensorEvalPerfTest

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_evaluation
    set_description("Test performance of tensor dot product vs feature dot product calculation")
    @graphs = get_graphs_dot_product
    deploy_and_feed(100000)

    [10,25,50,100,250,500].each do |wset_entries|
      run_fbench_helper(DOT_PRODUCT, FEATURE_DOT_PRODUCT, wset_entries, "queries.dot_product_wset.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, FEATURE_DOT_PRODUCT_ARRAY, wset_entries, "queries.dot_product_array.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, DENSE_TENSOR_DOT_PRODUCT, wset_entries, "queries.tensor.dense.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, DENSE_FLOAT_TENSOR_DOT_PRODUCT, wset_entries, "queries.tensor.dense_float.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, SPARSE_TENSOR_DOT_PRODUCT, wset_entries, "queries.tensor.sparse.x.#{wset_entries}.txt")
    end
  end

  def get_graphs_dot_product
    [
      get_latency_graphs_for_rank_profile(FEATURE_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(FEATURE_DOT_PRODUCT_ARRAY),
      get_latency_graphs_for_rank_profile(DENSE_TENSOR_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(DENSE_FLOAT_TENSOR_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,              250, 40.0, 45.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT_ARRAY,        500, 15.5, 16.8),
      get_latency_graph_for_rank_profile(DENSE_TENSOR_DOT_PRODUCT,         500, 16.9, 18.5),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,        250, 690, 820)
    ]
  end

  def teardown
    super
  end

end
