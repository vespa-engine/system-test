# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'app_generator/container_app'

class DefaultRootHandler < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that the default root handler is set up and working.")
    @valgrind = false
    deploy_app(ContainerApp.new.
                   container(Container.new))
    start
  end

  def test_default_root_handler
    result = vespa.container.values.first.http_get("localhost", 0, "/")
    json = result.body
    puts "Json output:\n" + json
    data = JSON.parse(json)
    assert(data.has_key? "handlers")
  end

  def teardown
    stop
  end

end
