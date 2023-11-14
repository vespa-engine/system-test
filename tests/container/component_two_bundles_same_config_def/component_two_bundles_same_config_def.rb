# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ComponentTwoBundlesSameConfigDef < SearchContainerTest

  def setup
    set_owner("musum")
    set_description("Test that deployment of an application with two bundles containing the same config definition fails unless deploying with -f option.")
  end

  def test_two_bundles_same_def
    add_bundle_dir(File.expand_path(selfdir + "bundle1"), "com.yahoo.vespatest.ExtraHitSearcher")
    add_bundle_dir(File.expand_path(selfdir + "bundle2"), "com.yahoo.vespatest.ExtraHitSearcher2")
    assert_raise(ExecuteError) {
      output = deploy(selfdir+"app")
    }
#    output = deploy(selfdir+"app", nil, {:force => true})
#    wait_for_application(vespa.qrs['default'].qrserver['0'], output)
  end

  def teardown
    stop
  end

end
