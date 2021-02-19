# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorFeedSinglePerfTest < MixedTensorPerfTestBase

  def test_single_model_vec_256
    set_description("Test feed performance (put, assign, add) for single model mixed tensor with vector size 256")
    set_owner("geirst")
    @graphs = get_graphs_vec_256
    deploy_and_compile("vec_256")

    @num_docs = 240000
    warmup_feed("-d 1 -o #{@num_docs/10} -f model")
    # Tensor cells data is: 3 * 256 * 4 = 3k
    feed_and_profile_cases("-d 3 -o #{@num_docs} -f model")
  end

  def get_graphs_vec_256
    [
      get_all_feed_throughput_graphs,
      get_feed_throughput_graph(PUTS, NUMBER, 4250, 5600),
      get_feed_throughput_graph(PUTS, STRING, 4500, 5600),
      get_feed_throughput_graph(UPDATES_ASSIGN, NUMBER, 4300, 5500),
      get_feed_throughput_graph(UPDATES_ASSIGN, STRING, 4400, 5500),
      get_feed_throughput_graph(UPDATES_ADD, NUMBER, 11400, 14000),
      get_feed_throughput_graph(UPDATES_ADD, STRING, 11400, 14000),
      get_feed_throughput_graph(UPDATES_REMOVE, NUMBER, 24000, 29000),
      get_feed_throughput_graph(UPDATES_REMOVE, STRING, 24000, 29000)
    ]
  end

  def test_single_model_vec_32
    set_description("Test feed performance (put, assign, add) for single model mixed tensor with vector size 32")
    set_owner("geirst")
    @graphs = get_graphs_vec_32
    deploy_and_compile("vec_32")

    @num_docs = 80000
    warmup_feed("-d 1 -v 32 -o #{@num_docs/10} -f model")
    # Tensor cells data is: 80 * 32 * 4 = 10k
    feed_and_profile_cases("-c 1000 -d 80 -v 32 -o #{@num_docs} -f model")
  end

  def get_graphs_vec_32
    [
      get_all_feed_throughput_graphs,
      get_feed_throughput_graph(PUTS, NUMBER, 1400, 1750),
      get_feed_throughput_graph(PUTS, STRING, 1300, 1700),
      get_feed_throughput_graph(UPDATES_ASSIGN, NUMBER, 1400, 1700),
      get_feed_throughput_graph(UPDATES_ASSIGN, STRING, 1300, 1700),
      get_feed_throughput_graph(UPDATES_ADD, NUMBER, 14000, 17000),
      get_feed_throughput_graph(UPDATES_ADD, STRING, 13500, 17000),
      get_feed_throughput_graph(UPDATES_REMOVE, NUMBER, 15000, 18000),
      get_feed_throughput_graph(UPDATES_REMOVE, STRING, 14000, 17500)
    ]
  end

  def teardown
    super
  end

end
