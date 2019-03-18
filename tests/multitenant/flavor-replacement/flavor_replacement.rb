# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'multitenant_test'
require 'application_v2_api'
require 'tenant_rest_api'

class FlavorReplacement < MultiTenantTest

  include ApplicationV2Api
  include TenantRestApi
  
  FLAVOR_A = "flavor_A"
  FLAVOR_B = "flavor_B"
  FLAVOR_C = "flavor_C"
  FLAVOR_DEF = FLAVOR_A
  
  def initialize(*args)
    super(*args)
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def setup
    super
    set_owner("mortent")
    set_description("Tests flavor replacement in hosted Vespa")

    @use_shared_configservers = false
    # Set default flavor and zone
    override_environment_setting(@configserver, "cloudconfig_server.default_flavor", FLAVOR_DEF)
    override_environment_setting(@configserver, "cloudconfig_server.environment", "prod")
    override_environment_setting(@configserver, "cloudconfig_server.region", "us-west-1")
  end

  def test_platform_owner_adds_similar_flavor_existing_application
    replace_node_repo_config("#{selfdir}node-repo-config/node-flavors_A.xml")
    start_configserver
    @configserver.ping_configserver

    #Add flavor A nodes and deploy
    add_flavored_nodes(10,FLAVOR_A)
    deploy_app_v2_api(selfdir + "app_default_flavor")
    allocated_nodes_before_replaces = get_allocated_nodes

    #Add flavor B, restart configserver
    replace_node_repo_config("#{selfdir}node-repo-config/node-flavors_B_repl_A.xml")
    @configserver.stop_configserver(:keep_everything=>true)
    @configserver.start_configserver
    @configserver.ping_configserver
    
    #Add 10 flavor B nodes and redeploy 
    add_flavored_nodes(10,FLAVOR_B)
    deploy_app_v2_api(selfdir + "app_default_flavor")
    allocated_nodes_after_replaces = get_allocated_nodes
    
    #assert deployed app has same number of nodes
    assert_equal(allocated_nodes_before_replaces, allocated_nodes_after_replaces)
  end

  def test_platform_owner_adds_similar_flavor_new_application
    #Purpose: Make sure we can get nodes even though we don't have enough of either flavor
    
    # Set default flavor and add container specific default flavor, set flavor B replaces A
    replace_node_repo_config("#{selfdir}node-repo-config/node-flavors_B_repl_A.xml")    
    start_configserver
    @configserver.ping_configserver
    
    #Add 4 nodes of each flavor. Note that application requires a total of 5
    add_flavored_nodes(4,FLAVOR_A)
    add_flavored_nodes(4,FLAVOR_B)
    
    #Deploy application, verify that we have 5 nodes
    deploy_app_v2_api(selfdir + "app_default_flavor")
    allocated_nodes = get_allocated_nodes
    assert_equal(5, allocated_nodes["nodes"].length)
  end
  
  def test_platform_owner_adds_similar_flavor_new_application_specific_flavor
    #Purpose: Make sure we can get nodes even though we don't have enough of either flavor
    
    # Set default flavor and add container specific default flavor, set flavor B replaces A
    replace_node_repo_config("#{selfdir}node-repo-config/node-flavors_B_repl_A.xml")    
    start_configserver
    @configserver.ping_configserver
    
    #Add 4 nodes of each flavor. Note that application requires a total of 5
    add_flavored_nodes(4,FLAVOR_A)
    add_flavored_nodes(4,FLAVOR_B)
    
    #Deploy application, verify that we have 5 nodes
    deploy_app_v2_api(selfdir + "app_specific_flavor")
    allocated_nodes = get_allocated_nodes
    assert_equal(5, allocated_nodes["nodes"].length)
  end

  
  def add_flavored_nodes(num, flavor)
    nodes = (1..num).collect do |i|
      "node-#{flavor}-#{i}".downcase()
    end
    add_provisioned_hosts(@configserver, nodes, flavor)
  end

  def get_allocated_nodes
    application_dotted_string = "#{@tenant_name}.#{@application_name}.default"
    JSON.parse(http_request_get(URI("http://#{@configserver.hostname}:19071/nodes/v2/node/?application=#{application_dotted_string}")).body)
  end
  
  def teardown
    delete_application
    stop
    super
  end
end
