# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class EventLoggingTest < IndexedSearchTest

  def setup
    set_owner("hmusum")
    set_description("Tests event logging API with a mock backend")
  end

  def test_event_logging
    add_bundle_dir(File.expand_path(selfdir + '/project'), 'test')
    deploy(selfdir + "application/")
    start
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA + "music.10.xml")

    search("query=blues&searchChain=logging")
    search("query=delta&searchChain=logging")
    search("query=female&searchChain=logging")
    search("query=modern&searchChain=logging")

    sleep 5 # Give spooler some time to process files
    container = vespa.container.values.first
    result = container.http_get2("/events")
    assert_equal("{\"count\":4}", result.body)
  end

  def teardown
    stop
  end

end
