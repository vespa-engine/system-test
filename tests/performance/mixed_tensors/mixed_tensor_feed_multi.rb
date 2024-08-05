# Copyright Vespa.ai. All rights reserved.
require_relative 'mixed_tensor_base'

class MixedTensorFeedMultiPerfTest < MixedTensorPerfTestBase

  def test_multi_model_vec_256
    set_description("Test feed performance (put, assign, add) for multi-model (direct) mixed tensor with vector size 256")
    set_owner("geirst")
    deploy_and_compile("vec_256/direct", "vec_256")

    @num_docs = 30000
    warmup_feed("-d 1 -o #{@num_docs/2} -f models")
    # Tensor cells data is: 10 (model) * 3 (cat) * 256 * 4 = 30k
    feed_and_profile_cases("-d 3 -o #{@num_docs} -f models")
  end

  def teardown
    super
  end

end
