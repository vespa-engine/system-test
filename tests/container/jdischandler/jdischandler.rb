# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class JDiscHandler < SearchContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Deploy and run a JDisc handler along with search.")
    add_bundle(selfdir + "HelloWorld.java")
    @valgrind = false
    deploy(selfdir+"app")
    start
    @container = vespa.container["container/0"]
  end

  def test_handler
    result = @container.search("/HelloWorld")
    assert_match(Regexp.new("Hello, world!"), result.xmldata, "Could not find expected message in response.")
  end

  def test_reconfig_bindings
    output = deploy(selfdir+"app2")
    wait_for_application(@container, output)

    result = @container.search("/ReconfiguredHelloWorld")
    assert_match(Regexp.new("Hello, world!"), result.xmldata, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
