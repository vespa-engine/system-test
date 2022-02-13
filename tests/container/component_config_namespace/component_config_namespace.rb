# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ComponentConfigNamespace < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that config classes can be exchanged between bundles. A searcher in bundle 'b' extends a configurable searcher from bundle 'a', which requires that the config class is exported from bundle 'a'.")
  end

  def test_component_config_namespace
    exporter = add_bundle_dir(selfdir+'project/exporter', 'com.yahoo.exporter.ExporterSearcher')
    importer = add_bundle_dir(selfdir+'project/importer', 'com.yahoo.importer.ImporterSearcher', :dependencies => [exporter])

    compile_bundles(@vespa.nodeproxies.values.first)

    deploy(selfdir+"app", nil, :bundles => [exporter, importer])
    start

    result = search("query=test")
    assert_equal(3, result.hit.length);
  end

  def test_same_config_name_different_namespace
    set_owner("musum")
    # The searchers use config with name "foo", but from different namespaces
    searcher1 = add_bundle_dir(selfdir+'project/searcher1', 'com.yahoo.searcher1')
    searcher2 = add_bundle_dir(selfdir+'project/searcher2', 'com.yahoo.searcher2')

# todo add case where searcher uses two configs with same name, but different namespace (foo@bar and foo@xyzzy) (one from another bundle)
#    searcher3 = add_bundle_dir(selfdir+'project/searcher3', 'com.yahoo.searcher3', '', '', '')

    compile_bundles(@vespa.nodeproxies.values.first)

    output = deploy(selfdir+"app2", nil, :bundles => [searcher1, searcher2])
    start

    result = search("query=test&searchChain=no1")
    assert_equal(1, result.hit.length);
    assert_equal("Searcher1 title", result.hit[0].field["title"])

    result = search("query=test&searchChain=no2")
    assert_equal(1, result.hit.length);
    assert_equal(42, result.hit[0].field["number"])
  end

  def teardown
    stop
  end

end
