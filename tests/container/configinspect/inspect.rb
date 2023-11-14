# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/search_app'

class ConfigInspect < SearchContainerTest

  def setup
    set_owner('aressem')
    set_description('Test config inspection')
    deploy_app(SearchApp.new().sd(selfdir+'simple.sd'))
    start
  end

  def test_config_status_util
    r = vespa_config_status
    assert_equal(0, r[0].to_i, "System ended up with wrong config generation on start:\n#{r[1]}")
    config_generation = get_generation(deploy_app(SearchApp.new().sd(selfdir+'simple.sd'))).to_i
    wait_for_reconfig(config_generation, 600, true)
  end

  def teardown
    stop
  end

end
