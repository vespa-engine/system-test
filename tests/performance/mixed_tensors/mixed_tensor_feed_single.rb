# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorFeedSinglePerfTest < MixedTensorPerfTestBase

  def test_single_model_feed
    set_description("Test feed performance (put, assign, add) for single model mixed tensor")
    @graphs = get_graphs
    deploy_and_compile

    @num_docs = 300000
    feed_and_profile("puts model #{@num_docs}", PUTS)
    feed_and_profile("updates assign model #{@num_docs}", UPDATES_ASSIGN)
    feed_and_profile("updates add model #{@num_docs}", UPDATES_ADD)
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
