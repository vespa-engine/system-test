# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/container_app'
require 'app_generator/rest_api'
require 'container_test'
require 'json'

class BasicJersey2 < ContainerTest
  include AppGenerator

  def setup
    set_owner("gjoranv")
    set_description("Verify that rest-api applications can be deployed with jersey2.")

    add_bundle_dir(selfdir + "hello", "basic_jersey2")
    app = ContainerApp.new.container(
        Container.new.
            jetty(true).
            rest_api(RestApi.new('rest/api').
                         bundle(Bundle.new('basic_jersey2'))))
    start(app)
  end

  def test_basic_jersey2
    hello_world_should_work
    application_wadl_should_work

    pojo_json_mapping_should_work
  end

  def hello_world_should_work
    result = @container.search("/rest/api/hello")
    assert_equal("Hello from rest-api!", result.xmldata, "Did not get expected response.")
  end

  def application_wadl_should_work
    result = @container.search("/rest/api/application.wadl")
    assert(result.xmldata.include?("resource path=\"/hello\""), "application.wadl failed.")
  end

  def pojo_json_mapping_should_work
    result = @container.http_get("localhost", 0, "/rest/api/json")
    json = result.body
    puts "Json output:\n" + json
    data = JSON.parse(json)
    assert(data.has_key? "message")
    assert(data.has_key? "JsonProperty Integer")

    assert_equal("Hello JSON!", data["message"], "POJO JSON mapping failed")
    assert_equal(3, data["JsonProperty Integer"], "Did not get expected someInt.")
  end

  def teardown
    stop
  end

end
