# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'

class ZooKeeper < CloudConfigTest

  def setup
    set_description("Tests that ZooKeeper version used is the wanted one")
    set_owner("musum")
  end

  def test_zookeeper_version
    deploy_app(CloudconfigApp.new)

    output = vespa.nodeproxies.values.first.execute("echo srvr|nc localhost 2181|head -n 1")
    expected_version = "3.6"
    assert(output.start_with?("Zookeeper version: #{expected_version}"),
           "Expected ZooKeeper version to be #{expected_version}, another version found in output: #{output}")
  end

  def teardown
    stop
  end
end
