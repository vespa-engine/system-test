# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class JDiscClient < SearchContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Deploy a container with a custom JDisc client.")
    add_bundle(selfdir + "DispatchHandler.java")
    add_bundle_dir(selfdir, "com.yahoo.vespatest.DemoClient")
    @valgrind = false
    deploy(selfdir+"app")
    start
  end

  def test_client
    container = vespa.container["container/0"]
    result = container.search("/DispatchHandler")
    assert(result.xmldata =~ /Response handled by DispatchHandler./)
    assert(result.xmldata =~ /DemoClient says: Hello, world!/)

    # test server binding
    result = container.search("/DemoClient")
    assert_match(Regexp.new("DemoClient says: Hello, world!"), result.xmldata, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
