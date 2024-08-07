# Copyright Vespa.ai. All rights reserved.
require 'container_test'
require 'app_generator/container_app'

class ConfiguredHandler < ContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Deploy a configurable handler, and redeploy with changed config")
  end

  def test_configured_handler
    handler = add_bundle_dir(selfdir, "com.yahoo.vespatest.HelloWorld", :name => 'handler')
    compile_bundles(@vespa.nodeproxies.values.first)

    start(create_application('Hello, World!'), :bundles => [handler])
    verify_response('Hello, World!')

    # Redeploy with same bundle, but modified configured greeting
    deploy(create_application('Hello again!'), :bundles => [handler])
    verify_response('Hello again!')
  end

  def verify_response(expected)
    result = @container.search("/test")
    assert_match(/#{expected}/, result.xmldata, "Did not get expected response.")
  end

  def create_application(greeting)
    config = ConfigOverride.new(:"com.yahoo.vespatest.response").
        add("response", greeting)

    ContainerApp.new.container(
        Container.new.
            handler(Handler.new("com.yahoo.vespatest.HelloWorld").
                        binding("http://*/test").
                        config(config)))
  end

  def teardown
    stop
  end

end
