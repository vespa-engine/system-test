# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorFeedSinglePerfTest < MixedTensorPerfTestBase

  def test_single_model_vec_256
    set_description("Test feed performance (put, assign, add) for single model (direct) mixed tensor with vector size 256")
    set_owner("geirst")
    deploy_and_compile("vec_256/direct", "vec_256")

    @num_docs = 240000
    warmup_feed("-d 1 -o #{@num_docs/10} -f model")
    # Tensor cells data is: 3 * 256 * 4 = 3k
    feed_and_profile_cases("-d 3 -o #{@num_docs} -f model")
  end

  def teardown
    super
  end

end
