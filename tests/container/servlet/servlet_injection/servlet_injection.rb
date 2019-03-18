# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/container_app'
require 'app_generator/servlet'
require 'container_test'

class ServletInjection < ContainerTest
  include AppGenerator

  SERVLET_BUNDLE = 'basic_injection'

  def setup
    set_owner("nobody")
    set_description("Verify that Components can be injected into Servlets.")

    add_bundle_dir(selfdir + "servlet", "basic_injection")

    app = ContainerApp.new.container(
        Container.new.
            component(Component.new('injected').
                          klass('com.yahoo.test.InjectedComponent').
                          bundle(SERVLET_BUNDLE)).
            servlet(Servlet.new("my-servlet").
                        klass("com.yahoo.test.servlet.ServletWithComponentInjection").
                        bundle(SERVLET_BUNDLE).
                        path("myapp")))

    start(app)
  end

  def test_servlet_injection
    result = @container.search("/myapp")
    assert_equal("Hello, World!", result.xmldata, "Did not get expected response.")
  end

  def teardown
    stop
  end
end

