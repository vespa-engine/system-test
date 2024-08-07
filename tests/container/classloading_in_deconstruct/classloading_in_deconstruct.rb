# Copyright Vespa.ai. All rights reserved.
require 'container_test'
require 'app_generator/container_app'

class ClassloadingInDeconstruct < ContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Deploys a component that loads a new class in its deconstruct method, " +
                        "to verify that the bundle classloader is still functioning.")
  end

  def test_classloading_in_deconstruct
    exporter = add_bundle_dir(selfdir+"exporter", "com.yahoo.exporter.Exporter",
                              {:name => 'exporter'})

    importer = add_bundle_dir(selfdir+"importer", "com.yahoo.importer.DeconstructSearcher",
                              {
                                  :name => 'importer',
                                  :dependencies => [exporter],
                                  # Enforce import-package for the package loaded in the importer's deconstruct().
                                  # The bundle-plugin will not generate an import because the importer only refers to it in a String.
                                  :bundle_plugin_config => "<importPackage>com.yahoo.exporter</importPackage>"
                              })

    compile_bundles(@vespa.nodeproxies.values.first)

    start(original_application, :bundles => [exporter, importer])

    @container.logctl("qrserver:com.yahoo.container.jdisc.component", "debug=on")

    verify_response('Hello, World!')

    # Redeploy with no bundles, to enforce uninstall
    deploy(updated_application, :bundles => [])


    sleep_period = 70
    puts "Sleeping #{sleep_period} seconds for importer to be deconstructed."
    sleep(sleep_period)

    assert_log_matches(/Successfully retrieved message from exporter in deconstruct: Successfully called!/)
    assert_log_matches(/Uninstalling bundle com.yahoo.importer.DeconstructSearcher/)
    assert_log_matches(/Uninstalling bundle com.yahoo.exporter.Exporter/)
  end

  def verify_response(expected)
    result = @container.search("/search/")
    assert_match(/#{expected}/, result.xmldata, "Did not get expected response.")
  end

  def original_application
    ContainerApp.new(false).
        container(Container.new.search(Searching.new.
            chain(Chain.new.add(
                Searcher.new("com.yahoo.importer.DeconstructSearcher")))))
  end

  def updated_application
    ContainerApp.new(false).
        container(Container.new.search(Searching.new))
  end

  def teardown
    # The current searcher will be deconstructed here
    stop
  end

end
