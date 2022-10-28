# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class MalformedQueryReturns400 < ContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Check HTTP 400 is returned when sending malformed queries.")
  end

  def test_query_with_raw_space
    app = ContainerApp.new.container(Container.new)

    start(app)
    client = @container.https_client.create_client(@container.hostname, @container.http_port)
    response = client.request(Net::HTTP::Get.new('/t est\"'))

    assert_equal('400', response.code)
  end

  def teardown
    stop
  end

end
