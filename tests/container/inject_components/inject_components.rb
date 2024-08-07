# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class InjectComponents < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify the various combinations of component injection that are currently working.")

    add_bundle_dir(selfdir, "my_bundle")
    deploy(selfdir + "app")
    start
  end

  def test_component_injection
    result = vespa.container.values.first.search("/test")
    assert_equal("HandlerTakingComponent got GenericComponent got NestedGenericComponent",
                 result.xmldata,
                 "Did not get expected response.")
  end

  def teardown
    stop
  end

end
