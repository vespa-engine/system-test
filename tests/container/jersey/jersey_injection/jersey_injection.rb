# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'json'

class JerseyInjection < ContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that jdisc components can be injected to Jersey resources.")

    add_bundle_dir(selfdir + "hello", "hello")
    start(selfdir + "app")
  end

  def test_basic_jersey_injection
    data = get_json_data
    volatile_resource_id = data["resourceId"]
    @singleton_injected_id = data["injectedId"]

    # Do another request to verify that the injected component is still the same instance.
    data = get_json_data
    assert_not_equal(volatile_resource_id, data["resourceId"], "Weird... Same resource for two requests.")
    assert_equal(@singleton_injected_id, data["injectedId"], "Injected component was reconstructed between requests.")

    redeploy_rebuilt_bundle
  end

  def redeploy_rebuilt_bundle
    # Just redeploy the same app, as the bundle will be rebuilt, triggering reconstruction of the resource
    deploy(selfdir + "app")

    # Verify that the injected component has been reconstructed
    data = get_json_data
    assert_not_equal(@singleton_injected_id, data["injectedId"], "Injected component was not reconstructed after redeploy.")
  end

  def get_json_data
    result = @container.http_get("localhost", 0, "/rest-api/hello")
    json = result.body
    puts "Json output:\n" + json
    data = JSON.parse(json)
    assert(data.has_key? "resourceId")
    assert(data.has_key? "injectedId")
    data
  end

  def teardown
    stop
  end

end
