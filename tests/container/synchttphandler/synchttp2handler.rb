# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'app_generator/container_app'

class SyncHttp2Handler < SearchContainerTest

  def setup
    set_owner("jonmv")
    set_description("Check it's possible to deploy sync HTTP/2 handlers")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.HelloWorld")
    @valgrind = false
    @container_port = Environment.instance.vespa_web_service_port
    deploy_app(ContainerApp.new.
      container(Container.new.
        handler(Handler.new("com.yahoo.vespatest.HelloWorld").
          binding("http://*/hello")).
        http(Http.new.
          server(
            Server.new('default', @container_port)).
          server(
            Server.new('plain-text-port', @container_port + 1).
              config(ConfigOverride.new('jdisc.http.connector').
                add('implicitTlsEnabled', 'false')))))) # Disable implicit TLS when Vespa mTLS setup is enabled
    start
    @container = vespa.container.values.first
    @adminserver = vespa.adminserver
    @expected_response = 'Hello, Factory!'
  end

  def test_synchttphandler
    endpoint = "localhost:#{@container_port}/hello?name=Factory"
    if @tls_env.tls_enabled?
      args = "--no-verify-peer --key #{@tls_env.private_key_file} --cert #{@tls_env.certificate_file} https://#{endpoint}"
    else
      args = "http://#{endpoint}"
    end
    @container.execute("nghttp --stat #{args}")
    response = @adminserver.execute("nghttp #{args}")
    assert_equal(@expected_response, response.strip)
  end

  def test_http2_plain_text_with_prior_knowledge
    response = @adminserver.execute("nghttp #{plain_text_http_url}")
    assert_equal(@expected_response, response.strip)
  end

  def test_http2_plain_text_with_upgrade
    # This test fail sometimes with the client failing to perform the upgrade. It's either caused by a bug in Jetty or nghttp2.
    # ("Failed to parse HTTP Upgrade response header: (HPE_INVALID_CONSTANT) invalid constant string")
    retries = 5
    for i in 0..retries
      response = @adminserver.execute("nghttp --upgrade #{plain_text_http_url}")
      if response.strip == @expected_response
        return
      end
      puts "Expected response containing '#{@expected_response}' but got '#{response}'. Retry ##{i + 1}"
      sleep(2)
    end
    fail("Failed to perform HTTP/2 upgrade after #{retries} retries")
  end

  def plain_text_http_url
    "http://localhost:#{@container_port + 1}/hello?name=Factory"
  end

  def teardown
    stop
  end

end

