# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/container_app'
require 'app_generator/servlet'
require 'container_test'

class ServletLifecycle < ContainerTest
  include AppGenerator

  def self.testparameters
    { "CLUSTER" => { :deploy_mode => "CLUSTER" } }
  end

  def setup
    set_owner('gv')
    set_description('Verify that servlets are taken up and down according to services config')

    @servlet_bundle = add_bundle_dir(selfdir + 'servlet', 'lifecycle-servlet', :name => 'resource')
    compile_bundles(@vespa.nodeproxies.values.first)
  end

  def test_servlet_lifecycle
    servlets = [simple_servlet('servlet1'),
                simple_servlet('servlet2')]
    start(create_application(servlets), :bundles => [@servlet_bundle])
    verify_servlet_response('servlet1')
    verify_servlet_response('servlet2')

    # Removing servlet2
    servlets = [simple_servlet('servlet1')]
    deploy(create_application(servlets), :bundles => [@servlet_bundle])
    verify_servlet_response('servlet1')
    assert_response_code('/servlet2', 404)

    # Adding servlet3
    servlets = [simple_servlet('servlet1'),
                simple_servlet('servlet3')]
    deploy(create_application(servlets), :bundles => [@servlet_bundle])
    verify_servlet_response('servlet1')
    verify_servlet_response('servlet3')

    # Must stop before checking the log to get the final destroy messages
    @container.stop
    verify_log_messages
  end

  def verify_servlet_response(servlet)
    verify_response("/#{servlet}", "Hello #{servlet}")
  end

  def verify_log_messages
    verify_init_and_destroy('servlet1', 3)
    verify_init_and_destroy('servlet2', 1)
    verify_init_and_destroy('servlet3', 1)
  end

  def verify_init_and_destroy(servlet, times)
    assert_equal(times, assert_log_matches("init #{servlet}"))
    assert_equal(times, assert_log_matches("destroy #{servlet}"))
  end

  def create_application(servlets)
    servlet_container = Container.new
    servlets.each do |s|
      servlet_container.servlet(s)
    end

    ContainerApp.new.container(servlet_container)
  end

  def simple_servlet(path)
    Servlet.new(path).
        klass('com.yahoo.test.servlet.ServletWithId').
        bundle('lifecycle-servlet').
        path(path)

  end

  def verify_response(path, expected)
    result = @container.search(path)
    assert_match(/#{expected}/, result.xmldata, 'Did not get expected response.')
  end

  def assert_response_code(path, expected)
    response = @container.http_get('localhost', 0, path)
    assert_equal(expected, response.code.to_i, "HTTP Response code #{response.code} doesn't match expected value (#{expected}) Response returned: #{response}")
  end

  def teardown
    stop
  end

end
