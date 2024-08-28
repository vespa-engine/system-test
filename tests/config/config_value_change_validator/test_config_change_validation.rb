# Copyright Vespa.ai. All rights reserved.
require 'app_generator/container_app'
require 'config_test'

class ConfigChangeValidation < ConfigTest

  def setup
    set_description("Test config change validator in config server.")
    set_owner("bjorncs")
  end

  def test_config_change_validation
    deploy_app(ContainerApp.new.container(Container.new))

    app_with_changed_config = ContainerApp.new.container(Container.new)
    app_with_changed_config.config(ConfigOverride.new('search.config.qr-start').
                  add('jdisc', ConfigValue.new('classpath_extra', 'swag.jar ')))
    output = deploy_app(app_with_changed_config)

    # Assert that the log contains an entry refering to the changed restart config.
    assert_match(/Restart services of type 'container'/, output)
    assert_match(/qr-start\.jdisc\.classpath_extra has changed from \"\" to \"swag\.jar \"/, output)

  end

  def teardown
    stop
  end
end
