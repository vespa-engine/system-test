# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'app_generator/container_app'

class ProcessingBasic < SearchContainerTest

  def setup
    @valgrind = false
    set_owner("bratseth")
    set_description("Deploy and run a Processor.")
    add_bundle("#{selfdir}/HelloWorld.java")
    deploy_app(ContainerApp.new(false)\
        .container(Container.new.processing(
            Processing.new.chain(ProcessorChain.new.add(
                Processor.new("com.yahoo.vespatest.HelloWorld"))))))
    start
  end

  def test_handler
    result = search("/processing/?chain=default")
    assert_match(Regexp.new("Hello, world!"), result.xmldata,
                 "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
