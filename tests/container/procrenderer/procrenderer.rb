# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'

class ProcessingRenderer < SearchContainerTest

  def setup
    set_owner("bratseth")
    set_description("Deploy and run processing renderers.")
    @valgrind = false
    add_bundle_dir(selfdir, "com.yahoo.vespatest.BasicRenderer")
    app = ContainerApp.new.processing(
        Processing.new.renderer(
          Renderer.new("basic", "com.yahoo.vespatest.BasicRenderer"))\
        .chain(ProcessorChain.new.add(
          Processor.new("com.yahoo.vespatest.NopProcessor")\
            .bundle("com.yahoo.vespatest.BasicRenderer"))))
    deploy_app(app)
    start
  end

  def test_renderer
    container = vespa.container.values.first
    result = container.search("/processing/?format=basic")
    assert_match(Regexp.new("Hello, world!"), result.xmldata, "Could not find expected message in response.")
    result = container.search("/processing/?tracelevel=9")
    assert_match(Regexp.new("NopProcessor"), result.xmldata, "Could not find expected message in response.")
    # repeat, as it is possible to screw up in that regar
    result = container.search("/processing/?format=basic")
    assert_match(Regexp.new("Hello, world!"), result.xmldata, "Could not find expected message in response.")
    result = container.search("/processing/?tracelevel=9")
    assert_match(Regexp.new("NopProcessor"), result.xmldata, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
