# Copyright Vespa.ai. All rights reserved.
require 'config_test'

class SubscribeFromUnknownHost < ConfigTest

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def can_share_configservers?
    false
  end

  def setup
    set_owner("musum")
    set_description("Tests that getting config from another host than defined in an application package will get config from default tenant and application")
  end

  def test_subscribe_from_host_outside_vespa_instance
    deploy_app(ConfigApp.new)
    config_server = vespa.configservers["0"]
    if (config_server.hostname == @vespa.nodeproxies.values[0].hostname)
      external_node = @vespa.nodeproxies.values[1]
    else
      external_node = @vespa.nodeproxies.values[0]
    end
    assert_config(config_server.hostname, 19070, external_node)
  end

  def assert_config(configserver_hostname, configserver_port, node_proxy)
    config = node_proxy.execute("vespa-get-config -n cloud.config.log.logd -i admin -s #{configserver_hostname} -p #{configserver_port} | grep host")
    assert_equal("logserver.host \"#{configserver_hostname}\"", config.chomp)
  end

  def teardown
    stop
  end
end
