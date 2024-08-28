# Copyright Vespa.ai. All rights reserved.
require 'cloudconfig_test'

class ServerRestart < CloudConfigTest

  def setup
    set_description("Tests that the config proxy returns correct config even when server restarts and is cleaned between deployments.")
    # See ticket 5838877 for background and additional info for this test
    set_owner("musum")
  end

  def test_server_restart_and_clean
    @valgrind = false
    deploy(selfdir+"app")
    start
    node = vespa.adminserver
    # Check that we get expected config before deploying a new app with changed config
    assert_logd_config(node, 86400)
    restart_config_server(node)
    # wait until config proxy logs APPLICATION_NOT_LOADED response from server (the time is dependent on timeouts in TimingValues.java)
    wait_for_atleast_log_matches(/No application exists/, 1)
    # deploy twice to get to a new generation number (2)
    deploy(selfdir+"app")
    deploy(selfdir+"app_changed")
    assert_logd_config(node, 1234)
  end

  def assert_logd_config(node, expected_age)
    @getconfig = "vespa-get-config -w 10 -t 8"
    timeout = 120
    config = ""
    timeout.times {
      begin
        age = getvespaconfig('cloud.config.log.logd', 'admin')['rotate']['age']
        if age == expected_age
          return true
        end
      rescue Exception => e
        puts "Got exception, will retry: " + e.message
      end
      sleep 1
    }
    # If we get here we could not get correct config from config proxy,
    # the code below is to check whether config from config server is correct
    config_from_server = getvespaconfig('cloud.config.log.logd', 'admin', nil, node, 19070)
    assert_equal(expected_age, config_from_server['rotate']['age'])
    raise "Could not get correct config from config proxy in #{timeout} seconds. " +
      "config:\n#{config}\nrotate.age should be #{expected_age}. Config from server is correct:\n#{config_from_server}"
  end

  def teardown
    stop
  end
end
