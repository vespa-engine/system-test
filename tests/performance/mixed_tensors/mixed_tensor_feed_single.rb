# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorFeedSinglePerfTest < MixedTensorPerfTestBase

  def test_single_model_feed
    set_description("Test feed performance (put, assign, add) for single model mixed tensor")
    @graphs = get_graphs
    deploy_and_compile

    @num_docs = 300000
    feed_and_profile("-o #{@num_docs} -f model puts", PUTS, NUMBER)
    feed_and_profile("-o #{@num_docs} -f model updates assign", UPDATES_ASSIGN, NUMBER)
    feed_and_profile("-o #{@num_docs} -f model updates add", UPDATES_ADD, NUMBER)

    feed_and_profile("-o #{@num_docs} -f model -s puts", PUTS, STRING)
    feed_and_profile("-o #{@num_docs} -f model -s updates assign", UPDATES_ASSIGN, STRING)
    feed_and_profile("-o #{@num_docs} -f model -s updates add", UPDATES_ADD, STRING)
  end

  def get_graphs
    [
      get_feed_throughput_graph(PUTS, NUMBER, 1, 30000),
      get_feed_throughput_graph(PUTS, STRING, 1, 30000),
      get_feed_throughput_graph(UPDATES_ASSIGN, NUMBER, 1, 30000),
      get_feed_throughput_graph(UPDATES_ASSIGN, STRING, 1, 30000),
      get_feed_throughput_graph(UPDATES_ADD, NUMBER, 1, 30000),
      get_feed_throughput_graph(UPDATES_ADD, STRING, 1, 30000)
    ]
  end

  def teardown
    super
  end

end
