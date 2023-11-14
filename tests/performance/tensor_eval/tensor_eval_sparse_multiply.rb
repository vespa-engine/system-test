# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/tensor_eval/tensor_eval'

class TensorEvalSparseMultiplyPerfTest < TensorEvalPerfTest

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_evaluation_sparse_multiply
    set_description("Test performance of various sparse tensor multiply use cases")
    deploy_and_feed(5000)

    [10,50,100].each do |entries|
      run_fbench_helper(SPARSE_MULTIPLY, SPARSE_MULTIPLY_NO_OVERLAP, entries, "queries.tensor.sparse.y.#{entries}.txt")
    end

    [5,10,50].each do |entries|
      run_fbench_helper(SPARSE_MULTIPLY, SPARSE_MULTIPLY_PARTIAL_OVERLAP, entries, "queries.tensor.sparse.yz.#{entries}.txt")
    end
  end

  def teardown
    super
  end

end
