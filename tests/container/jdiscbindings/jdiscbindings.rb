# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class JDiscFilterAndHandlerBindingsTest < ContainerTest

  BUNDLE_NAME = 'app-bundle'
  PORT = 8080
  PATH = '/myhandler'
  HANDLER_BINDING = "http://*:#{PORT}#{PATH}"
  HOST_HEADER_WITH_INVALID_PORT = 'localhost:1234'

  def setup
    set_owner("bjorncs")
    set_description("Verify uri binding matching for filter and handler")
  end

  def test_request_matches_bindings_with_invalid_port_in_host_header
    add_bundle_dir(selfdir + 'app-bundle', BUNDLE_NAME)
    app = ContainerApp.new.container(
        Container.new.
            http(Http.new.
                filter_chain(ResponseFilterChain.new('host-header-response-chain').
                    filter(HttpFilter.new('host-header-response-filter', 'test.HostHeaderResponseFilter', BUNDLE_NAME)).
                    binding(HANDLER_BINDING)).
                filter_chain(RequestFilterChain.new('host-header-request-chain').
                    filter(HttpFilter.new('host-header-request-filter', 'test.HostHeaderRequestFilter', BUNDLE_NAME)).
                    binding(HANDLER_BINDING)).
                server(Server.new('test-server', PORT))).
            handler(Handler.new("test.HostHeaderHandler").
                        bundle(BUNDLE_NAME).
                        binding(HANDLER_BINDING)))

    start(app)
    response = @container.http_get2(PATH, {"Host" => HOST_HEADER_WITH_INVALID_PORT})
    puts "Response code: #{response.code.to_i}"
    puts "Response headers: #{response.each_header.to_h}"
    assert_equal(response.code.to_i, 200)
    assert_equal(response.body(), "OK")
    assert_equal(PORT, response['Handler-Observed-Port'].to_i)
    assert_equal(PORT, response['Request-Filter-Observed-Port'].to_i)
    assert_equal(PORT, response['Response-Filter-Observed-Port'].to_i)
    assert_equal(HOST_HEADER_WITH_INVALID_PORT, response['Observed-Host-Header'])
  end

  def teardown
    stop
  end

end
