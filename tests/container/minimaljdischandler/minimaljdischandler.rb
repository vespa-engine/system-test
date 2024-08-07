# Copyright Vespa.ai. All rights reserved.
require 'container_test'
require 'app_generator/container_app'

class MinimalJDiscHandler < ContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Deploy and run a JDisc handler with minimal amount of Vespa stuff.")
  end

  def test_handler
    add_bundle(selfdir + "HelloWorld.java")
    app = ContainerApp.new.container(
        Container.new.
            handler(Handler.new("com.yahoo.vespatest.HelloWorld").
                        binding("http://*/test")))

    start(app)
    result = @container.search("/test")
    assert_match(/Hello, world!/, result.xmldata, "Did not get expected response.")
  end

  def teardown
    stop
  end

end
