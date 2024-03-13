# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class EventLoggingTest < IndexedSearchTest

  BUNDLE_NAME = 'eventloggingtest'

  def setup
    set_owner("hmusum")
    set_description("Tests event logging API with a mock backend")
  end

  def make_logging_search_chain
    Chain.new('logging', "vespa").add(Searcher.new('com.yahoo.example.LoggingSearcher', nil, nil, nil, BUNDLE_NAME))
  end

  def make_app_container(slow)
    eventstore = slow  ? 'EventStoreSlowReceiver' : 'EventStoreImpl'
    container = Container.new('default')
    container.component(Component.new('com.yahoo.example.SpoolingLogger').bundle(BUNDLE_NAME))
    container.component(Component.new("com.yahoo.example.#{eventstore}").bundle(BUNDLE_NAME))
    container.handler(Handler.new('com.yahoo.example.EventHandler').binding('http://*/events').bundle(BUNDLE_NAME))
    container.search(Searching.new.chain(make_logging_search_chain))
    container
  end

  def make_app(slow)
    app = SearchApp.new
    app.container(make_app_container(slow))
    app.sd(selfdir + 'schemas/music.sd')
    app
  end

  def test_event_logging
    add_bundle_dir(File.expand_path(selfdir + '/project'), BUNDLE_NAME)
    deploy_app(make_app(false))
    start
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA + "music.10.xml")

    count = 4
    do_queries(count)
    wait_for_event_count(count)
    container = vespa.container.values.first
    assert_equal("foo", get_last_blob(container.http_get2("/events")))

    deploy_output = deploy_app(make_app(true))
    wait_for_application(container, deploy_output)

    count = 100
    do_queries(count)
    wait_for_event_count(count)
  end

  # Wait for expected number of events having been received by backend
  def wait_for_event_count(expected_count)
    puts "Waiting for #{expected_count} events to be processed"
    container = vespa.container.values.first
    i = 0
    event_count = 0
    max_wait_time = 100
    loop do
      result = container.http_get2("/events")
      event_count = get_event_count(result)
      puts "Event count: #{event_count}"
      break if expected_count == event_count or i > max_wait_time
      sleep 1
      i = i + 1
    end
    puts "Waited #{i} seconds"
    assert_equal(expected_count, event_count)
  end

  def get_event_count(result)
    JSON.parse(result.body)['count']
  end

  def get_last_blob(result)
    JSON.parse(result.body)['lastBlob']
  end

  def do_queries(n)
    count = 0
    loop do
      search("query=blues&searchChain=logging")
      count = count + 1
      break if count >= n
    end
  end

  def teardown
    stop
  end

end
