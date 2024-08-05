# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class VespaDestinationTest < IndexedStreamingSearchTest

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
