# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class HandlerWithConfigProvider < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Deploy a configurable handler that takes a non-cloud config class")
    add_bundle_dir(selfdir, "mybundle")
    @valgrind = false
    deploy(selfdir+"app")
    start
  end

  def test_handler
    result = vespa.container.values.first.http_get2("/demo").body
    assert_match(Regexp.new("We can configure a jdisc handler that takes non-cloud config!"), result, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
