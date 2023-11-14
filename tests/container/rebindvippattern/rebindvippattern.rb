# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class RebindVipPattern < ContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Ensure we can override the default VIP handler binding with a binding with explicit port.")
  end

  def test_binding_override
    add_bundle(selfdir + "HelloWorld.java")
    default_app = ContainerApp.new
    start(default_app)
    result = @container.search("/status.html")
    assert_match(/OK/, result.xmldata, "Did not get expected response.")
    app_with_custom_binding = ContainerApp.new.container(
        Container.new.
            handler(Handler.new("com.yahoo.vespatest.HelloWorld").
                        binding("http://*:#{@container.http_port}/status.html")))
    deploy(app_with_custom_binding)
    result = @container.search("/status.html")
    assert_match(/Hello, world!/, result.xmldata, "Did not get expected response.")
  end

  def teardown
    stop
  end

end
