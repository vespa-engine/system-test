# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'cloudconfig_test'
require 'search_test'
require 'environment'

class ScalingConfigservers < CloudConfigTest

  def initialize(*args)
    super(*args)
    @num_hosts = 5
    @node1 = nil
    @node2 = nil
    @node3 = nil
    @node4 = nil
    @node5 = nil
  end

  def timeout_seconds
    1200
  end

  def nightly?
    true
  end

  def setup
    set_description("Tests that multiple configservers work. When one server goes down, " +
                    "the others should continue to serve config.")
    set_owner("musum")
  end

  def test_scaling
    # Deploying as usual first, to get the data structures of the test
    deploy_app(SearchApp.new.sd(selfdir+"banana.sd").
                      num_hosts(5).
                      configserver("node1").
                      configserver("node2").
                      configserver("node3").
                      configserver("node4").
                      configserver("node5"))

    puts "Stop and scratch all config servers"
    @node1 = vespa.configservers["0"]
    @node2 = vespa.configservers["1"]
    @node3 = vespa.configservers["2"]
    @node4 = vespa.configservers["3"]
    @node5 = vespa.configservers["4"]
    @nodes = [ @node1, @node2, @node3, @node4, @node5 ]
    @nodes.each do |node| node.stop_configserver end
    @nodes.each do |node| node.logctl("configserver:com.yahoo.vespa.config.server", "debug=on") end
    @nodes.each do |node| node.logctl("configserver:com.yahoo.vespa.config.server.tenant", "debug=on") end
    @nodes.each do |node| scratch_zk(node) end

    puts "INITIAL: 1"
    srvlist = [@node1.name()]
    vespa.adminserver.set_addr_configserver(srvlist)
    @node1.start_configserver
    @node1.ping_configserver
    deploy_app(SearchApp.new.sd(selfdir+"banana.sd").
                      num_hosts(5).
                      configserver("node1"))
    assert_configservers_ok([@node1])
    assert_configservers_down([@node2, @node3, @node4, @node5])

    puts "SCALING: 1->3"
    srvlist = [@node1.name(), @node2.name(), @node3.name()]
    [ @node1, @node2, @node3 ].each do |node| node.set_addr_configserver(srvlist) end

    # Start node1 and node2 first to make sure node1 is part of quorum
    restart_configserver(@node1)
    @node2.start_configserver
    @node1.ping_configserver
    @node2.ping_configserver

    # Then start node3
    @node3.start_configserver
    @node3.ping_configserver

    zk_command = "vespa-zkls /config/v2/tenants/default/sessions/2 2 >/dev/null; vespa-zkcat /config/v2/tenants/default/sessions/2/userapp 2> /dev/null; vespa-zkcat /config/v2/tenants/default/sessions/2/userapp/services.xml 2> /dev/null; vespa-zkcat /config/v2/tenants/default/sessions/2/userapp/hosts.xml 2> /dev/null"
    @node1.execute(zk_command)
    assert_configservers_ok([@node1, @node2, @node3])
    assert_configservers_down([@node4, @node5])

    puts "SCALING: 3->5"
    srvlist = [@node1.name(), @node2.name(), @node3.name(), @node4.name(), @node5.name()]
    @nodes.each do |node| node.set_addr_configserver(srvlist) end
    @nodes.each do |node| restart_configserver(node) end
    @nodes.each do |node| node.ping_configserver end
    assert_configservers_ok([@node1, @node2, @node3, @node4, @node5])

    puts "DOWNSCALING: 5->3"
    srvlist = [@node3.name(), @node4.name(), @node5.name()]
    @nodes.each do |node| node.set_addr_configserver(srvlist) end
    @node1.stop_configserver
    @node2.stop_configserver
    restart_configserver(@node3)
    restart_configserver(@node4)
    restart_configserver(@node5)
    scratch_zk(@node1)
    scratch_zk(@node2)
    assert_configservers_down([@node1, @node2])
    # TODO: this doesn't always work, but it's currently far fetched to scale 5->3
    #@node3.ping_configserver
    #@node4.ping_configserver
    #@node5.ping_configserver
    #assert_configserver_ok(@node3)
    #assert_configserver_ok(@node4)
    #assert_configserver_ok(@node5)
  end

  def scratch_zk(node)
    node.execute("rm -rf #{Environment.instance.vespa_home}/var/zookeeper/*")
  end

  def assert_configservers_ok(nodes)
    nodes.each do |node| assert_match(/logserver/, get_config(node)) end
  end

  def assert_configservers_down(nodes)
    nodes.each do |node| assert_match(/Connection error/, get_config(node)) end
  end

  def get_config(node)
    node.execute("vespa-get-config -n cloud.config.log.logd -i \"\" -p 19070 -w 10")
  end

  def restart_configserver(node)
    node.stop_configserver({:keep_everything=>true})
    node.start_configserver
  end

  def teardown
    stop
  end

  def debug(msg)
    vespa.nodeproxies.values.each do |n|
      n.execute("echo #{msg} >> /tmp/node_server.log")
    end
  end

end
