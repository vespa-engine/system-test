# Copyright Vespa.ai. All rights reserved.

require 'performance/tensor_eval/tensor_eval'

class TensorEvalMatchPerfTest < TensorEvalPerfTest

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_evaluation_match
    set_description("Test performance of various expensive tensor matching use cases")
    deploy_and_feed(5000)

    [5,10,25].each do |dim_size|
      run_fbench_helper(MATCH, TENSOR_MATCH_25X25, dim_size, "queries.tensor.sparse.y.#{dim_size}.txt")
    end

    [5,10,25,50].each do |dim_size|
      run_fbench_helper(MATCH, TENSOR_MATCH_50X50, dim_size, "queries.tensor.sparse.y.#{dim_size}.txt")
    end

    [5,10,25,50,100].each do |dim_size|
      run_fbench_helper(MATCH, TENSOR_MATCH_100X100, dim_size, "queries.tensor.sparse.y.#{dim_size}.txt")
    end
  end

  def teardown
    super
  end

end
