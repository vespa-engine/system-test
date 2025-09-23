# Copyright Vespa.ai. All rights reserved.
require 'config_test'

class ZooKeeper < ConfigTest

  def setup
    set_description("Tests that ZooKeeper version used is the wanted one")
    set_owner("musum")
  end

  def test_zookeeper_version
    deploy_app(ConfigApp.new)

    output = vespa.nodeproxies.values.first.execute("vespa-zkflw localhost 2181 srvr | grep 'Zookeeper version'")
    expected_version = "3.9"
    assert(output.start_with?("Zookeeper version: #{expected_version}"),
           "Expected ZooKeeper version to be #{expected_version}, another version found in output: #{output}")
  end


end
