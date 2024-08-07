# Copyright Vespa.ai. All rights reserved.
require 'performance/tensor_eval/tensor_eval'

class TensorEvalNormalPerfTest < TensorEvalPerfTest

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_evaluation
    set_description("Test performance of tensor dot product vs feature dot product calculation")
    deploy_and_feed(100000)

    [10,50,250].each do |wset_entries|
      run_fbench_helper(DOT_PRODUCT, FEATURE_DOT_PRODUCT, wset_entries, "queries.dot_product_wset.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, FEATURE_DOT_PRODUCT_ARRAY, wset_entries, "queries.dot_product_array.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, DENSE_TENSOR_DOT_PRODUCT, wset_entries, "queries.tensor.dense.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, DENSE_FLOAT_TENSOR_DOT_PRODUCT, wset_entries, "queries.tensor.dense_float.#{wset_entries}.txt")
      run_fbench_helper(DOT_PRODUCT, SPARSE_TENSOR_DOT_PRODUCT, wset_entries, "queries.tensor.sparse.x.#{wset_entries}.txt")
    end
  end

  def teardown
    super
  end

end
