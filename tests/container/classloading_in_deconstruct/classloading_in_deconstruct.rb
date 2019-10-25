# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class ClassloadingInDeconstruct < ContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Deploys a component that loads a new class in its deconstruct method, " +
                        "to verify that the bundle classloader is still functioning.")
  end

  def test_classloading_in_deconstruct
    searcher = add_bundle_dir(selfdir, "com.yahoo.vespatest.DeconstructSearcher", :name => 'searcher')
    compile_bundles(@vespa.nodeproxies.values.first)

    start(create_application('Hello, World!'), :bundles => [searcher])
    verify_response('Hello, World!')

    # Redeploy with same bundle, but modified configured message
    deploy(create_application('Hello again!'), :bundles => [searcher])
    verify_response('Hello again!')

    sleep_period = 70
    puts "Sleeping #{sleep_period} seconds for old searcher to be deconstructed."
    sleep(sleep_period)
  end

  def verify_response(expected)
    result = @container.search("/search/")
    assert_match(/#{expected}/, result.xmldata, "Did not get expected response.")
  end

  def create_application(message)
    config = ConfigOverride.new(:"com.yahoo.vespatest.response").
        add("response", message)

    ContainerApp.new(false).
        container(Container.new.search(Searching.new.
            chain(Chain.new.add(
                Searcher.new("com.yahoo.vespatest.DeconstructSearcher").
                    config(config)))))
  end

  def teardown
    # The current searcher will be deconstructed here
    stop
  end

end
