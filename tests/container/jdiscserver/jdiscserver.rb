# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class JDiscServer < SearchContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Deploy a container with a custom JDisc server.")
    add_bundle_dir(selfdir, "com.yahoo.vespatest.DemoServer")
    @valgrind = false
    deploy(selfdir+"app")
    start
  end

  def test_server
    # port for this is defined in test config
    result = vespa.container["container/0"].search("/ignored", 16889)
    assert_match(Regexp.new("Hello, world!"), result.xmldata, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
