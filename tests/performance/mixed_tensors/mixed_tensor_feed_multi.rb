# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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

  def test_multi_model_vec_32
    set_description("Test feed performance (put, assign, add) for multi-model (direct) mixed tensor with vector size 32")
    set_owner("geirst")
    deploy_and_compile("vec_32")

    @num_docs = 10000
    warmup_feed("-c 900 -d 70 -v 32 -o #{@num_docs} -f models")
    # Tensor cells data is: 10 (model) * 80 (cat) * 32 * 4 = 100k
    feed_and_profile_cases("-c 1000 -d 80 -v 32 -o #{@num_docs} -f models")
  end

  def teardown
    super
  end

end
