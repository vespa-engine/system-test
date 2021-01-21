# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_block_base'
require 'http_client'

class FeedBlockTest < FeedBlockBase

  def test_feed_block_http_client
    set_description("Test resource based feed block (in proton) using high performance http client")
    @num_parts = 1
    deploy_app(get_app)
    start
    node = vespa.adminserver

    # Baseline
    http_client_feed_file("docs.1.json")
    assert_hitcount("query=sddocname:test", 1)
    assert_hitcount("query=w1", 1)

    # Force trigger of memory limit
    redeploy_app(0.0, 1.0, 1.0, 1.0)
    assert_http_client_feed(/memoryLimitReached/, 11)
    # Force trigger of disk limit
    redeploy_app(1.0, 0.0, 1.0, 1.0)
    assert_http_client_feed(/diskLimitReached/, 12)
    # Force trigger of enum store limit
    redeploy_app(1.0, 1.0, 0.0, 1.0)
    assert_http_client_feed(/enumStoreLimitReached/, 11)
    # Force trigger of multivalue limit
    redeploy_app(1.0, 1.0, 1.0, 0.0)
    assert_http_client_feed(/multiValueLimitReached/, 12)

    # Allow feeding again
    redeploy_app(1.0, 1.0, 1.0, 1.0)
    http_client_feed_file("docs.2.json")
    assert_hitcount("query=sddocname:test", 2)
    assert_hitcount("query=w2", 1)
    http_client_feed_file("update.nontrivial.1.json")
    assert_hitcount("query=w11", 1)
  end

  def http_client_feed_file(file_name)
    feed(:file => selfdir + file_name, :client => :vespa_http_client)
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


  def test_feed_block_document_v1_api
    set_description("Test resource based feed block (in proton) using document v1 api")
    @num_parts = 1
    deploy_app(get_app)
    start
    feed_and_test_document_v1_api
  end

  def http_v1_api_put(http, id)
    puts "Putting doc with id #{id}"
    url = "/document/v1/#{@namespace}/#{@doc_type}/docid/#{id}"
    httpHeaders = {}
    http_v1_api_post(http,
                     url,
                     "{ \"fields\": { \"a1\" : [ \"w#{id}\" ] } }",
                     httpHeaders)
  end

  def assert_document_v1_feed_failed(http, pattern)
    response = http_v1_api_put(http, 2)
    assert_equal("507", response.code)
    assert_match(pattern, response.body)
    assert_hitcount("query=sddocname:test&nocache", 1)
    assert_hitcount("query=w2&nocache", 0)
  end

  def feed_and_test_document_v1_api
    http = https_client.create_client(vespa.document_api_v1.host, vespa.document_api_v1.port)
    http.read_timeout=190
    response = http_v1_api_put(http, 1)
    assert_equal("200", response.code)
    assert_json_string_equal(
                             '{"pathId":"/document/v1/test/test/docid/1", "id":"id:test:test::1"}',
                             response.body)
    assert_hitcount("query=sddocname:test&nocache", 1)
    assert_hitcount("query=w1&nocache", 1)
    # Force trigger of memory limit
    redeploy_app(0.0, 1.0, 1.0, 1.0)
    assert_document_v1_feed_failed(http, /memoryLimitReached/)
    # Force trigger of disk limit
    redeploy_app(1.0, 0.0, 1.0, 1.0)
    assert_document_v1_feed_failed(http, /diskLimitReached/)
    assert_hitcount("query=sddocname:test&nocache", 1)
    assert_hitcount("query=w32&nocache", 0)
    # Force trigger of enum store limit
    redeploy_app(1.0, 1.0, 0.0, 1.0)
    assert_document_v1_feed_failed(http, /enumStoreLimitReached/)
    # Force trigger of multivalue limit
    redeploy_app(1.0, 1.0, 1.0, 0.0)
    assert_document_v1_feed_failed(http, /multiValueLimitReached/)
    # Allow feeding again
    redeploy_app(1.0, 1.0, 1.0, 1.0)
    response = http_v1_api_put(http, 2)
    assert_equal("200", response.code)
    assert_json_string_equal(
                             '{"pathId":"/document/v1/test/test/docid/2", "id":"id:test:test::2"}',
                             response.body)
    assert_hitcount("query=sddocname:test&nocache", 2)
    assert_hitcount("query=w2&nocache", 1)
  end

  def feed_and_test_document_v1_api_into_limit(http)
    @beforelimit.times do |x|
      id = 1 + x
      response = http_v1_api_put(http, id)
      assert_equal("200", response.code)
    end
    sample_sleep
    # Currently have @beforelimit documents, below limit
    response = http_v1_api_put(http, @beforelimit + 1)
    assert_equal("200", response.code)
    sample_sleep
    # Currently have beforelimit + 1 documents, above limit
    response = http_v1_api_put(http, @beforelimit + 2)
    assert_equal("507", response.code)
    assert_match(/multiValueLimitReached/, response.body)
  end

  def feed_and_test_document_v1_api_two_nodes_resumed(http)
    # Currently have @beforelimit + 1 documents, but now spread over two nodes
    response = http_v1_api_put(http, @beforelimit + 2)
    assert_equal("200", response.code)
  end

  def test_feed_block_document_v1_api_two_nodes
    set_description("Test resource based feed block (in proton) using document v1 api, attribute resource limit, and node addition for recovery")
    @num_parts = 2
    @beforelimit = 37
    # Allow feeding, but with very low multivalue limit, allows @beforelimit docs
    deploy_app(get_app.config(get_configoverride(1.0, 1.0, 1.0, 0.00000001)))
    start
    puts "Stopping content node 1 to run in degraded mode with only 1 node up"
    get_node(1).stop
    puts "Sleep #{@sleep_delay} seconds to allow content node 1 to stop"
    sleep @sleep_delay
    settle_cluster_state("uimrd")
    http = https_client.create_client(vespa.document_api_v1.host, vespa.document_api_v1.port)
    feed_and_test_document_v1_api_into_limit(http)
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
    feed_and_test_document_v1_api_two_nodes_resumed(http)
  end

end
