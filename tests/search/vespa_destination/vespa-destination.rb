# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class VespaDestinationTest < IndexedSearchTest

  def setup
    set_owner("balder")
  end

  def test_vespa_destination
    set_description("Test that vespa-destination is able to run and display help text.")
    node = vespa.nodeproxies.values.first
    node.execute("vespa-destination --help |grep \"Simple receiver for messagebus messages. Prints the messages received to stdout.\"")
  end

  def teardown
    stop
  end

end
