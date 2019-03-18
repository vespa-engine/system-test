# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/container_app'
require 'app_generator/rest_api'
require 'container_test'
require 'json'

class Jersey2Reconfig < ContainerTest
  include AppGenerator

  def setup
    set_owner('gv')
    set_description('Verify that jersey2 applications can be reconfigured.')
  end

  def test_jersey2_reconfig
    resource = add_bundle_dir(selfdir + "project", "jersey2_reconfig", :name => 'resource')
    compile_bundles(@vespa.nodeproxies.values.first)

    start(create_application('Hello!'), :bundles => [resource])
    verify_response('Hello!')

    # Redeploy with same bundle, but modified configured greeting
    deploy(create_application('Hello again!'), :bundles => [resource])
    verify_response('Hello again!')
  end

  def create_application(message)
    message_config = ConfigOverride.new('com.yahoo.test.message').
        add('message', message)

    ContainerApp.new.container(
        Container.new.
            component(Component.new('injected').
                          klass('com.yahoo.test.InjectedComponent').
                          bundle('jersey2_reconfig').
                          config(message_config)).
            rest_api(RestApi.new('rest-api').
                         bundle(Bundle.new('jersey2_reconfig'))))
  end

  def verify_response(expected)
    result = @container.search("/rest-api/hello")
    assert_match(/#{expected}/, result.xmldata, "Did not get expected response.")
  end

  def teardown
    stop
  end

end
