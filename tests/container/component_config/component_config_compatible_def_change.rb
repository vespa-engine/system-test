# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ComponentConfigDefVersion < SearchContainerTest

  def setup
    set_owner("musum")
    set_description("Test that application packages with components that a compatible change in a config definition will work.")
  end

  def test_two_searchers_same_def_compatible_change
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.ExtraHitSearcher")
    deploy(selfdir+"app")
    start
    @qrs = (vespa.qrserver.values.first or vespa.container.values.first)
    @qrs.logctl(@qrs.servicetype + ':com.yahoo.container.di', 'debug=on')

    result = search("query=test")
    title = result.hit[0].field["title"]
    assert_equal("Heal the World!", title)

    clear_bundles
    add_bundle_dir(File.expand_path(selfdir)+"/src2", "com.yahoo.vespatest.ExtraHitSearcher2")
    output = deploy(selfdir+"app_same_def_compatible_change")
    wait_for_application(@qrs, output)

    result = search("query=test&searchChain=no2")
    puts "#{result}"
    title = result.hit[0].field["title"]
    assert_equal("Mind 2 times!", title)
  end

  def teardown
    stop
  end

end
