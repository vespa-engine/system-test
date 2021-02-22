# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorFeedMultiPerfTest < MixedTensorPerfTestBase

  def test_multi_model_vec_256
    set_description("Test feed performance (put, assign, add) for multi-model mixed tensor with vector size 256")
    set_owner("geirst")
    @graphs = get_graphs_vec_256
    deploy_and_compile("vec_256")

    @num_docs = 30000
    warmup_feed("-d 1 -o #{@num_docs/2} -f models")
    # Tensor cells data is: 10 (model) * 3 (cat) * 256 * 4 = 30k
    feed_and_profile_cases("-d 3 -o #{@num_docs} -f models")
  end

  def get_graphs_vec_256
    [
      get_all_feed_throughput_graphs,
      get_feed_throughput_graph(PUTS, NUMBER, 490, 600),
      get_feed_throughput_graph(PUTS, STRING, 490, 600),
      get_feed_throughput_graph(UPDATES_ASSIGN, NUMBER, 490, 600),
      get_feed_throughput_graph(UPDATES_ASSIGN, STRING, 490, 600),
      get_feed_throughput_graph(UPDATES_ADD, NUMBER, 3200, 4000),
      get_feed_throughput_graph(UPDATES_ADD, STRING, 3200, 4000),
      get_feed_throughput_graph(UPDATES_REMOVE, NUMBER, 8500, 10500),
      get_feed_throughput_graph(UPDATES_REMOVE, STRING, 8000,  9500)
    ]
  end

  def test_multi_model_vec_32
    set_description("Test feed performance (put, assign, add) for multi-model mixed tensor with vector size 32")
    set_owner("geirst")
    @graphs = get_graphs_vec_32
    deploy_and_compile("vec_32")

    @num_docs = 10000
    warmup_feed("-c 900 -d 70 -v 32 -o #{@num_docs} -f models")
    # Tensor cells data is: 10 (model) * 80 (cat) * 32 * 4 = 100k
    feed_and_profile_cases("-c 1000 -d 80 -v 32 -o #{@num_docs} -f models")
  end

  def get_graphs_vec_32
    [
      get_all_feed_throughput_graphs,
      get_feed_throughput_graph(PUTS, NUMBER, 135, 170),
      get_feed_throughput_graph(PUTS, STRING, 135, 170),
      get_feed_throughput_graph(UPDATES_ASSIGN, NUMBER, 135, 165),
      get_feed_throughput_graph(UPDATES_ASSIGN, STRING, 135, 165),
      get_feed_throughput_graph(UPDATES_ADD, NUMBER, 950, 1250),
      get_feed_throughput_graph(UPDATES_ADD, STRING, 900, 1200),
      get_feed_throughput_graph(UPDATES_REMOVE, NUMBER, 3500, 4300),
      get_feed_throughput_graph(UPDATES_REMOVE, STRING, 3000, 3800)
    ]
  end

  def teardown
    super
  end

end
