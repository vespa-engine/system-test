# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_container_test'
require 'app_generator/container_app'

class ProcessingAndSearch < SearchContainerTest

  def setup
    @valgrind = false
    set_owner("bratseth")
    set_description("Deploy and run processing chains and search chains in one container.")
    add_bundle(selfdir + "SimpleSearcher.java")
    add_bundle(selfdir + "ProcessorOne.java")
    add_bundle(selfdir + "ProcessorTwo.java")

    deploy_app(ContainerApp.new.
        container(Container.new.
          search(Searching.new.
            chain(Chain.new("default").add(
              Searcher.new("com.yahoo.search.systemtest.SimpleSearcher")))).
          processing(Processing.new.
            chain(ProcessorChain.new("default").add(
              Processor.new("com.yahoo.vespatest.ProcessorOne"))).
            chain(ProcessorChain.new("other").add(
              Processor.new("com.yahoo.vespatest.ProcessorTwo")).add(
              Processor.new("com.yahoo.vespatest.ProcessorOne"))))).
        logserver("node1").
        slobrok("node1"))

    start
  end

  def test_processing_and_search_chains_in_one_container
    @qrs = (vespa.qrserver.values.first or vespa.container.values.first)
    result = @qrs.search("/search/?query=test")
    assert_match(Regexp.new("search chains and processing chains in one container!"), result.xmldata,
                 "Could not find expected message in response.")

    result = @qrs.search("/processing/")
    assert_match(Regexp.new("Processing chain with one Processor"), result.xmldata,
                 "Could not find expected message in response.")

    result = @qrs.search("/processing/?chain=other")
    assert_match(Regexp.new("Processing chain with one Processor"), result.xmldata,
                 "Could not find expected message in response.")
    assert_match(Regexp.new("No, make that two!"), result.xmldata,
                 "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
