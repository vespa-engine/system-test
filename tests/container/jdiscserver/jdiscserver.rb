# Copyright Vespa.ai. All rights reserved.
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
    uri = URI("http://#{vespa.container["container/0"].hostname}:16889/ignored")
    response = Net::HTTP.get_response(uri)
    assert_match(Regexp.new("Hello, world!"), response.body, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
