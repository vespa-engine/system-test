# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorFeedMultiPerfTest < MixedTensorPerfTestBase

  def test_multi_model_feed
    set_description("Test feed performance (put, assign, add) for multi-model mixed tensor")
    @graphs = get_graphs
    deploy_and_compile

    @num_docs = 30000
    feed_and_profile("puts models #{@num_docs}", PUTS)
    feed_and_profile("updates assign models #{@num_docs}", UPDATES_ASSIGN)
    feed_and_profile("updates add models #{@num_docs}", UPDATES_ADD)
  end

  def get_graphs
    [
      get_feed_throughput_graph(PUTS, 1, 30000),
      get_feed_throughput_graph(UPDATES_ASSIGN, 1, 30000),
      get_feed_throughput_graph(UPDATES_ADD, 1, 30000)
    ]
  end

  def teardown
    super
  end

end
