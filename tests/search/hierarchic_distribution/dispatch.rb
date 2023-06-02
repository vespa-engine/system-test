# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_and_query_test_base'

class HierarchicDistributionDispatchTest < FeedAndQueryTestBase

  def setup
    set_owner("geirst")
    super
  end

  def timeout_seconds
    60 * 80
  end

  def test_dispatch_when_nodes_down_and_up_with_less_ready_copies
    set_description("Test that dispatch can handle nodes going down in a fixed group/row when doing search, using less ready copies than redundancy")
    run_nodes_down_and_up_test(3)
  end

  def test_dispatch_when_nodes_down_and_up
    set_description("Test that dispatch can handle nodes going down in a fixed group/row when doing search")
    run_nodes_down_and_up_test(6)
  end

  def clear_query_counts_bias(index_to_clear)
    @query_counts_bias[index_to_clear] = 0
    puts "clear_query_counts_bias(#{index_to_clear}): #{array_to_s(@query_counts_bias)}"
  end

  def run_nodes_down_and_up_test(ready_copies)
    deploy_app(create_app(3, ready_copies))
    configure_bucket_crosschecking(6)
    start
    generate_and_feed_docs
    sleep 10 # This is a sleep to allow all services to complete startup and settle as many services start on the same host.
    align_dispatch_to_use_group_0_next

    assert_query_hitcount # group 0
    assert_num_queries([1, 1, 1, 0, 0, 0, 0, 0, 0])
    assert_query_hitcount # group 1
    assert_num_queries([1, 1, 1, 1, 1, 1, 0, 0, 0])
    assert_query_hitcount # group 2
    assert_num_queries([1, 1, 1, 1, 1, 1, 1, 1, 1])

    # take down group 0
    stop_and_not_wait(0)
    stop_and_not_wait(1)
    stop_and_not_wait(2)
    sleep 1 # We need at least one ping round to establish group coverage
    assert_response_code_from_vip_handler(200)
    assert_query_hitcount # group 1
    assert_num_queries([nil, nil, nil, 2, 2, 2, 1, 1, 1])
    assert_query_hitcount # group 2
    assert_num_queries([nil, nil, nil, 2, 2, 2, 2, 2, 2])
    assert_query_hitcount # group 1
    assert_num_queries([nil, nil, nil, 3, 3, 3, 2, 2, 2])
  end

  def assert_response_code_from_vip_handler(expected_response_code, path="/status.html")
    qrserver = vespa.container.values.first
    s_name = qrserver.name
    s_port = qrserver.http_port

    assert_nothing_raised() { TCPSocket.new(s_name, s_port) }

    assert_nothing_raised() {
      response = https_client.get(s_name, s_port, path)
      assert_equal(expected_response_code.to_s, response.code);
    }
  end

end
