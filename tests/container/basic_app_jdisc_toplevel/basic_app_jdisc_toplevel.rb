# Copyright Vespa.ai. All rights reserved.

require "search_container_test"

class BasicAppJdiscToplevel < SearchContainerTest

  def setup
    set_owner("bratseth")
    set_description("Tests that a services.xml with jdisc on top level and no nodes deploys properly")
    deploy(selfdir+"app")
    start
  end

  def test_basic_app_jdisc_toplevel
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
