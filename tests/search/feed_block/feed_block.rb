# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_block_base'
require 'http_client'

class FeedBlockTest < FeedBlockBase

  def test_proton_feed_block_http_client
    set_owner("geirst")
    set_description("Test resource based feed block (in proton) using high performance http client")
    run_feed_block_http_client_test({ :memory => /memoryLimitReached/,
                                      :disk => /diskLimitReached/,
                                      :address_space => /addressSpaceLimitReached/ })
  end

  def test_distributor_feed_block_http_client
    set_owner("geirst")
    set_description("Test resource based feed block (in distributor) using high performance http client")
    @block_feed_in_distributor = true
    run_feed_block_http_client_test(expected_distributor_error_messages)
  end

  def expected_distributor_error_messages
    { :memory => /memory on node/,
      :disk => /disk on node/,
      :address_space => /attribute-address-space:test\.ready\.a1\..* on node/ }
  end

  def run_feed_block_http_client_test(error_msg)
    @num_parts = 1
    deploy_app(get_app)
    start

    # Baseline
    http_client_feed_file("docs.1.json")
    assert_hitcount("query=sddocname:test", 1)
    assert_hitcount("query=w1", 1)

    # Force trigger of memory limit
    redeploy_app(0.0, 1.0, 1.0)
    assert_http_client_feed(error_msg[:memory], 11)
    # Force trigger of disk limit
    redeploy_app(1.0, 0.0, 1.0)
    assert_http_client_feed(error_msg[:disk], 12)
    # Force trigger of address space limit
    redeploy_app(1.0, 1.0, 0.0)
    assert_http_client_feed(error_msg[:address_space], 11)

    # Allow feeding again
    redeploy_app(1.0, 1.0, 1.0)
    http_client_feed_file("docs.2.json")
    assert_hitcount("query=sddocname:test", 2)
    assert_hitcount("query=w2", 1)
    http_client_feed_file("update.nontrivial.1.json")
    assert_hitcount("query=w11", 1)
  end

  def assert_http_client_feed(pattern, update_value)
    assert_http_client_put_blocked(pattern)
    assert_http_client_non_trivial_update_blocked(pattern)
    assert_http_client_trivial_update_not_blocked(update_value)
  end

  def assert_http_client_put_blocked(pattern)
    feed_result = http_client_feed_file("docs.2.json")
    assert_match(pattern, feed_result)
    assert_hitcount("query=sddocname:test", 1)
    assert_hitcount("query=w2", 0)
  end

  def assert_http_client_non_trivial_update_blocked(pattern)
    feed_result = http_client_feed_file("update.nontrivial.1.json")
    assert_match(pattern, feed_result)
    assert_hitcount("query=w11", 0)
  end

  def assert_http_client_trivial_update_not_blocked(update_value)
    feed_result = http_client_feed_file("update.trivial.#{update_value}.json")
    assert_hitcount("query=a2:#{update_value}", 1)
  end


  def test_proton_feed_block_document_v1_api
    set_owner("geirst")
    set_description("Test resource based feed block (in proton) using document v1 api")
    run_feed_block_document_v1_api_test({ :memory => /memoryLimitReached/,
                                          :disk => /diskLimitReached/,
                                          :address_space => /addressSpaceLimitReached/ })
  end

  def test_distributor_feed_block_document_v1_api
    set_owner("geirst")
    set_description("Test resource based feed block (in distributor) using document v1 api")
    @block_feed_in_distributor = true
    run_feed_block_document_v1_api_test(expected_distributor_error_messages)
  end

  def run_feed_block_document_v1_api_test(error_msg)
    @num_parts = 1
    deploy_app(get_app)
    start

    vespa.document_api_v1.put(create_document(1))
    assert_hitcount("query=sddocname:test", 1)
    assert_hitcount("query=w1", 1)

    # Force trigger of memory limit
    redeploy_app(0.0, 1.0, 1.0)
    assert_document_v1_feed(error_msg[:memory], 11)
    # Force trigger of disk limit
    redeploy_app(1.0, 0.0, 1.0)
    assert_document_v1_feed(error_msg[:disk], 12)
    # Force trigger of address space limit
    redeploy_app(1.0, 1.0, 0.0)
    assert_document_v1_feed(error_msg[:address_space], 11)

    # Allow feeding again
    redeploy_app(1.0, 1.0, 1.0)
    vespa.document_api_v1.put(create_document(2))
    assert_hitcount("query=sddocname:test", 2)
    assert_hitcount("query=w2", 1)
  end

  def create_document(id)
    Document.new(@doc_type, @id_prefix + id.to_s).
      add_field("a1", [ "w#{id}" ]).
      add_field("a2", id)
  end

  def assert_document_v1_feed(pattern, update_value)
    assert_document_v1_put_blocked(2, pattern)
    assert_hitcount("query=sddocname:test&nocache", 1)
    assert_hitcount("query=w2&nocache", 0)
    assert_document_v1_non_trivial_update_blocked(pattern)
    assert_document_v1_trivial_update_not_blocked(update_value)
  end

  def assert_document_v1_put_blocked(id, pattern)
    err = assert_raise(HttpResponseError) {
      vespa.document_api_v1.put(create_document(id))
    }
    assert_equal(507, err.response_code)
    assert_match(pattern, err.response_message)
  end

  def assert_document_v1_non_trivial_update_blocked(pattern)
    update = DocumentUpdate.new(@doc_type, @id_prefix + "1")
    update.addOperation("assign", "a1", ["w11"])
    err = assert_raise(HttpResponseError) {
      vespa.document_api_v1.update(update)
    }
    assert_equal(507, err.response_code)
    assert_match(pattern, err.response_message)
    assert_hitcount("query=w11", 0)
  end

  def assert_document_v1_trivial_update_not_blocked(update_value)
    update = DocumentUpdate.new(@doc_type, @id_prefix + "1")
    update.addOperation("assign", "a2", update_value)
    vespa.document_api_v1.update(update)
    assert_hitcount("query=a2:#{update_value}", 1)
  end


  def test_proton_feed_block_document_v1_api_two_nodes
    set_owner("geirst")
    set_description("Test resource based feed block (in proton) using document v1 api, attribute resource limit, and node addition for recovery")
    run_feed_block_document_v1_api_two_nodes_test({ :address_space => /addressSpaceLimitReached/ })
  end

  def test_distributor_feed_block_document_v1_api_two_nodes
    set_owner("geirst")
    set_description("Test resource based feed block (in distributor) using document v1 api, attribute resource limit, and node addition for recovery")
    @block_feed_in_distributor = true
    run_feed_block_document_v1_api_two_nodes_test({ :address_space => /attribute-address-space:test\.ready\.a1\.multi-value on node/ })
  end

  def run_feed_block_document_v1_api_two_nodes_test(error_msg)
    @num_parts = 2
    @beforelimit = 37
    # Allow feeding, but with very low multivalue limit, allows @beforelimit docs
    deploy_app_with_low_multivalue_limit
    start

    puts "Stopping content node 1 to run in degraded mode with only 1 node up"
    get_node(1).stop
    puts "Sleep #{@sleep_delay} seconds to allow content node 1 to stop"
    sleep @sleep_delay
    settle_cluster_state("uimrd")

    feed_and_test_document_v1_api_into_limit(error_msg)
    puts "Starting content node 1 to run in normal mode again with 2 nodes up"
    get_node(1).start
    puts "Sleep #{@sleep_delay} seconds to allow content node 1 to start"
    sleep @sleep_delay
    settle_cluster_state("ui")
    hit_count_query = "query=sddocname:test&nocache&model.searchPath=0/0"
    hit_count = @beforelimit + 1
    hit_count_toomany = hit_count / 2 + 4
    while hit_count >= hit_count_toomany
      puts "Waiting for node 0 hit count (currently #{hit_count}) to be less than #{hit_count_toomany}"
      hit_count = wait_for_not_hitcount(hit_count_query, hit_count, 180, 0)
    end
    puts "Node 0 hit count is now #{hit_count}"
    sample_sleep
    feed_and_test_document_v1_api_two_nodes_resumed()
  end

  def deploy_app_with_low_multivalue_limit
    app = get_app
    # The resource usage reporter noise level is set to 0.0 to ensure all samples from proton are sent to the cluster controller.
    # This is needed as we have very small deltas in attribute multi-value sampling.
    set_resource_limits(app, app, 1.0, 1.0, 0.00000001, 0.0)
    deploy_app(app)
  end

  def feed_and_test_document_v1_api_into_limit(error_msg)
    @beforelimit.times do |x|
      id = 1 + x
      vespa.document_api_v1.put(create_document(id))
    end
    sample_sleep
    # Currently have @beforelimit documents, below limit
    vespa.document_api_v1.put(create_document(@beforelimit + 1))
    sample_sleep
    # Currently have beforelimit + 1 documents, above limit
    assert_document_v1_put_blocked(@beforelimit + 2, error_msg[:address_space])
  end

  def feed_and_test_document_v1_api_two_nodes_resumed()
    # Currently have @beforelimit + 1 documents, but now spread over two nodes
    vespa.document_api_v1.put(create_document(@beforelimit + 2))
  end

end
