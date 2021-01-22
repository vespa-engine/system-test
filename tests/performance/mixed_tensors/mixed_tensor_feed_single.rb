# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorFeedSinglePerfTest < MixedTensorPerfTestBase

  def test_single_model_vec_256
    set_description("Test feed performance (put, assign, add) for single model mixed tensor with vector size 256")
    set_owner("geirst")
    @graphs = get_graphs_vec_256
    deploy_and_compile("vec_256")

    @num_docs = 240000
    # Tensor cells data is: 3 * 256 * 4 = 3k
    feed_and_profile_cases("-d 3 -o #{@num_docs} -f model")
  end

  def get_graphs_vec_256
    [
      get_feed_throughput_graph(PUTS, NUMBER, 5100, 5550),
      get_feed_throughput_graph(PUTS, STRING, 5500, 5750),
      get_feed_throughput_graph(UPDATES_ASSIGN, NUMBER, 5400, 5750),
      get_feed_throughput_graph(UPDATES_ASSIGN, STRING, 5400, 5750),
      get_feed_throughput_graph(UPDATES_ADD, NUMBER, 12400, 14300),
      get_feed_throughput_graph(UPDATES_ADD, STRING, 12800, 14000),
      get_feed_throughput_graph(UPDATES_REMOVE, NUMBER, 27300, 30300),
      get_feed_throughput_graph(UPDATES_REMOVE, STRING, 27000, 32000)
    ]
  end

  def test_single_model_vec_32
    set_description("Test feed performance (put, assign, add) for single model mixed tensor with vector size 32")
    set_owner("geirst")
    @graphs = get_graphs_vec_32
    deploy_and_compile("vec_32")

    @num_docs = 80000
    # Tensor cells data is: 80 * 32 * 4 = 10k
    feed_and_profile_cases("-c 1000 -d 80 -v 32 -o #{@num_docs} -f model")
  end

  def get_graphs_vec_32
    [
      get_feed_throughput_graph(PUTS, NUMBER, 1550, 1750),
      get_feed_throughput_graph(PUTS, STRING, 1650, 1800),
      get_feed_throughput_graph(UPDATES_ASSIGN, NUMBER, 1600, 1800),
      get_feed_throughput_graph(UPDATES_ASSIGN, STRING, 1600, 1800),
      get_feed_throughput_graph(UPDATES_ADD, NUMBER, 15500, 18000),
      get_feed_throughput_graph(UPDATES_ADD, STRING, 16000, 18000),
      get_feed_throughput_graph(UPDATES_REMOVE, NUMBER, 16300, 19000),
      get_feed_throughput_graph(UPDATES_REMOVE, STRING, 16500, 19500)
    ]
  end

  def teardown
    super
  end

end
