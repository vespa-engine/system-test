# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/container_app'
require 'app_generator/servlet'
require 'container_test'

class BasicServlet < ContainerTest
  include AppGenerator

  def setup
    set_owner("nobody")
    set_description("Verify that custom servlets can be deployed with JDisc.")

    add_bundle_dir(selfdir + "servlet", "basic_servlet")

    app = ContainerApp.new.container(
        Container.new.
            servlet(Servlet.new("my-servlets").
                        klass("com.yahoo.test.servlet.HelloServlet").
                        bundle("basic_servlet").
                        path("my/app")))

    start(app)
  end

  def test_basic_servlet
    hello_world_should_work
  end

  def hello_world_should_work
    result = @container.search("/my/app")
    assert_equal("Hello, World!", result.xmldata, "Did not get expected response.")
  end

  def teardown
    stop
  end
end
