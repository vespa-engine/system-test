# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class ComponentUninitializedConfig < ContainerTest

  def setup
    set_owner("gjoranv")
    # Alas, the container cannot fail due to null config because it can happen in normal operation
    # when a component is removed from services.xml and the component takes a config with a
    # parameter that does not have a default value.
    set_description("Verify that the log mentions the uninitialized config parameter.")
  end

  # Standalone behaves correctly, the container does not come up.
  # Remove this if/when we can prevent the container from starting also in cluster mode.
  def self.testparameters
    { "CLUSTER" => { :deploy_mode => "CLUSTER" } }
  end

  def test_uninitialized_config_param
    handler = add_bundle_dir(selfdir, "com.yahoo.vespatest.HelloWorld", :name => 'handler')
    compile_bundles(@vespa.nodeproxies.values.first)

    add_expected_logged(/The following builder parameters for response must be initialized: \[response\]/)
    start(create_application, :bundles => [handler])
  end

  def create_application
    # Do not add config override to keep the 'response' config param uninitialized
    ContainerApp.new.container(
        Container.new.
            handler(Handler.new("com.yahoo.vespatest.HelloWorld").
                        binding("http://*/test")))
  end

  def teardown
    stop
  end

end
