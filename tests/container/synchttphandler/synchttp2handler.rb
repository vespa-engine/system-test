# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'

class SyncHttp2Handler < SearchContainerTest

  def setup
    set_owner("jonmv")
    set_description("Check it's possible to deploy sync HTTP/2 handlers")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.HelloWorld")
    @valgrind = false
    deploy_app(ContainerApp.new\
        .container(Container.new\
            .handler(Handler.new("com.yahoo.vespatest.HelloWorld")\
                .binding("http://*/hello"))))
    start
  end

  def test_synchttphandler
    container = vespa.container.values.first
    endpoint = "localhost:#{container.http_port}/hello?name=Factory"
    if @tls_env.tls_enabled?
      args = "--no-verify-peer --key #{@tls_end.private_key_file} --cert #{@tls_env.certificate_file} https://#{endpoint}"
    else
      args = "http://#{endpoint}"
    end
    container.execute("nghttp --stat #{args}")
    response = vespa.adminserver.execute("nghttp #{args}")
    assert "Hello, Factory!" == response.strip
  end

  def teardown
    stop
  end

end

