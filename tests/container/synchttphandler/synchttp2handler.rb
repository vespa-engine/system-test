# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
    assert "Hello, Factory!" == response.strip
  end

  def test_http2_plain_text_with_prior_knowledge
    response = @adminserver.execute("nghttp #{plain_text_http_url}")
    assert "Hello, Factory!" == response.strip
  end

  def test_http2_plain_text_with_upgrade
    response = @adminserver.execute("nghttp --upgrade #{plain_text_http_url}")
    assert "Hello, Factory!" == response.strip
  end

  def plain_text_http_url
    "http://localhost:#{@container_port + 1}/hello?name=Factory"
  end

  def teardown
    stop
  end

end

