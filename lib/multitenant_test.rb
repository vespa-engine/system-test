# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'testcase'
require 'tenant_rest_api'
require 'nodes_api'
require 'environment'

class MultiTenantTest < TestCase
  include NodesRestApi
  include TenantRestApi

  def initialize(*args)
    super(*args)
    @configserver = nil
    @orighostlist = nil
    @num_hosts = get_num_hosts + 1
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def get_num_hosts
    0
  end

  def modulename
    "multitenant"
  end

  def setup
    @configserver = vespa.nodeproxies.first[1]
    @use_shared_configservers = true
    @configserverhostlist = [@configserver.hostname]
    test_hosts = vespa.nodeproxies.map do |node|
        node[0]
    end
    test_hosts.shift
    @orighostlist = @hostlist
    @hostlist = test_hosts
    puts "Test hosts #{test_hosts}"
    @configserver.set_addr_configserver([@configserver.hostname])
    set_hosted_settings(@configserver)
  end

  def start_configserver
    @configserver.stop_configserver # Make sure new environment settings take effect
    @configserver.start_configserver
  end

  def add_flavored_nodes(num, flavor)
    nodes = (1..num).collect do |i|
      "node_#{flavor}_#{i}"
    end
    add_provisioned_hosts(@configserver, nodes, flavor)
  end

  def add_provisioned_hosts(configserver, test_hosts, flavor)
    add_nodes(test_hosts, configserver.hostname, flavor)
    dirty_nodes(test_hosts, configserver.hostname)
    ready_nodes(test_hosts, configserver.hostname)
  end

  def replace_node_repo_config(file)
    noderepoconfig = File.read(file)
    @configserver.writefile(noderepoconfig, "#{Environment.instance.vespa_home}/conf/configserver-app/node-flavors.xml")
  end

  def set_hosted_settings(node)
    override_environment_setting(node, "cloudconfig_server.multitenant", "true")
    override_environment_setting(node, "cloudconfig_server.hosted_vespa", "true")
    override_environment_setting(node, "cloudconfig_server.default_flavor", "medium")
    override_environment_setting(node, "vespa_node_repository.reservation_expiry", "120") # expire in 2 minutes
    override_environment_setting(node, "vespa_node_repository.inactive_expiry", "1") # expire in 1 second
    override_environment_setting(node, "vespa_node_repository.retired_expiry", "1")  # expire in 1 second
  end

  def teardown
    @configserver.stop_configserver if @configserver
    Environment.instance.reset_configserver(@configserver) if @configserver
    @configserver.execute("rm #{Environment.instance.vespa_home}/conf/configserver-app/node-flavors.xml")
    @use_shared_configservers = false
    @hostlist = @orighostlist if @orighostlist
    @configserverhostlist = []
  end
end
