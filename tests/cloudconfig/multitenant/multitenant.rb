# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'cloudconfig_test'
require 'json'
require 'set'
require 'environment'

# Note: How to run multi tenant systests.
#
# On the configserver, run
#
# yinst set cloudconfig_server.multitenant=true && yinst restart cloudconfig_server
# 
# When running test, run for example:
# sudo ruby systemtests/tests/cloudconfig/multitenant/multitenant.rb --configserverhost myconfigserver.trondheim.corp.yahoo.com
# 
# Remember --hostfile too if multi host test
#
# See also sudo ruby systemtests/tests/cloudconfig/multitenant/multitenant.rb --help
#

class MultiTenant < CloudConfigTest

  DEFAULT_TENANT = "default"
  TENANT_A = "a"
  TENANT_B = "b"

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def can_share_configservers?(method_name=nil)
    true
  end

  def setup
    super
    setup_test
  end

  def setup_test
    set_owner("musum")
    set_description("Tests deploying with multiple tenants")

    @tenant_name = DEFAULT_TENANT
    @application_name = "default"
    @environment = "prod"
    @region = "default"
    @instance = "default"
    @configserver = configserverhostlist[0]
    @hostname = @configserver
    if (!@configserver)
      raise "Could not get config server, check that you are using #{@num_hosts} hosts"
    end
  end

  def test_multi_tenant_deploy_many_times
    create_tenants_and_wait([TENANT_A, TENANT_B], @configserver)

    delete_application(@configserver, @tenant_name, @application_name)
    @tenant_name = TENANT_A
    @application_name = "foo"
    puts "deploying with tenant '#{@tenant_name}'"
    deploy_with_tenant("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", @tenant_name, @application_name)
    assert_config(1338, @configserver)
    puts "deploying with tenant '#{@tenant_name}'"
    deploy_with_tenant("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", @tenant_name, @application_name)
    assert_config(1338, @configserver)
    delete_tenant_and_its_applications(@hostname, TENANT_A)
    delete_tenant_and_its_applications(@hostname, TENANT_B)
  end

  # Tests requesting config from another tenant than default with v2 protocol
  def test_multi_tenant_client
    create_tenant_and_wait(TENANT_A, @configserver)
    @tenant_name = TENANT_A
    @application_name = "foo"
    fooValue = "SimpleApp a"
    add_bundle("simplebundle")
    service_name = "simpleapp_a"
    classpath = "#{Environment.instance.vespa_home}/lib/jars/config.jar"
    cmd = "cd #{dirs.tmpdir}/bundles; VESPA_CONFIG_ID=#{service_name} java -cp #{classpath}:simplebundle-1.0-deploy.jar com.yahoo.simpleapp.SimpleApp"
    puts "CMD=#{cmd}"
    app = generate_app(cmd, service_name, fooValue)
    deploy_generated(app, nil, nil, :tenant => @tenant_name, :application_name => @application_name)

    start
    sleep 10
    delete_tenant_and_its_applications(@hostname, TENANT_A)
    assert_config_output_in_log("foo: #{fooValue}")
  end

  def test_multiple_instances
    create_tenant_and_wait(TENANT_A, @configserver)
    @tenant_name = TENANT_A
    @application_name = "foo"
    @instance = "one"
    deploy_app_with_tenant(@hostlist[0], 1337)
    assert_logd_config_v2(1337, @configserver, @tenant_name, @application_name, @instance)
    @instance = "two"
    deploy_app_with_tenant(@hostlist[1], 1338)
    assert_logd_config_v2(1338, @configserver, @tenant_name, @application_name, @instance)
    assert_logd_config_v2(1337, @configserver, @tenant_name, @application_name, "one")
    delete_tenant_and_its_applications(@hostname, TENANT_A)
  end

  def multitenant_app(hostname, logserver_port)
    app_with_logd(logserver_port).host(AppHost.new(hostname, ["node1"]))
  end

  def test_subscribe_to_supermodel
    add_expected_logged(/got addPeer with .* check config consistency/)
    add_expected_logged(/configured partner list does not contain peer/)
    add_expected_logged(/Unable to send default state/)
    create_tenant_and_wait(TENANT_A, @configserver)
    create_tenant_and_wait(TENANT_B, @configserver)

    # One app on node2
    host_aliases = Set.new ["node2"]
    services = generate_services_with_alias
    path = generate_app_with_hosts("node2app", host_aliases, generate_services_with_alias)
    @tenant_name = TENANT_B
    @application_name = "bar"
    deploy_with_tenant(path, @tenant_name, @application_name, {:hosts_to_use => [hostlist[1]]})

    add_bundle("supermodelbundle")
    service_name = "supermodelclient"
    classpath = "#{Environment.instance.vespa_home}/lib/jars/config.jar"
    cmd = "cd #{dirs.tmpdir}/bundles; VESPA_CONFIG_ID=#{service_name} java -cp #{classpath}:supermodelbundle-1.0-deploy.jar com.yahoo.supermodelclient.SuperModelClient"
    puts "CMD=#{cmd}"
    app = generate_app(cmd, service_name, "foo")
    deploy_generated(app, nil, nil, :tenant => TENANT_A, :application_name => "foo")


    start
    assert_config_output_in_log("a,foo:prod:default:default,configproxy")
    assert_config_output_in_log("a,foo:prod:default:default,slobrok")
    assert_config_output_in_log("b,bar:prod:default:default,configproxy")
    assert_config_output_in_log("b,bar:prod:default:default,slobrok")
    assert_log_not_matches(/Exception/)
    vespa.stop_base # Need to stop services, because next deploy might give different/conflicting services on hosts

    # Add a jdisc cluster to the app and check that it is included in config
    app = generate_app2(cmd, service_name)
    deploy_generated(app, nil, nil, :tenant => TENANT_A, :application_name => "foo")
    start
    assert_config_output_in_log("a,foo:prod:default:default,configproxy")
    assert_config_output_in_log("a,foo:prod:default:default,slobrok")
    assert_config_output_in_log("a,foo:prod:default:default,qrserver")
    assert_config_output_in_log("a,foo:prod:default:default,slobrok2")
    assert_log_not_matches(/Exception/)
  end

  def add_bundle(name)
    clear_bundles
    add_bundle_dir(File.expand_path(selfdir+name), name)
  end

  def generate_app(cmd, service_name, fooValue)
    app=<<ENDER
<?xml version="1.0" encoding="utf-8" ?>
<services version="1.0">

  <admin version="2.0">
    <adminserver hostalias="node1" />
  </admin>

  <service id="simpleapp" name="#{service_name}" command="#{cmd}" version="1.0">
    <config name="bar2.baz_foo.simple">
      <foo>#{fooValue}</foo>
    </config>
    <node hostalias="node1" />
  </service>

</services>
ENDER
    return app
  end

  def generate_services_with_alias
    app=<<ENDER
<?xml version="1.0" encoding="utf-8" ?>
<services version="1.0">

  <admin version="2.0">
    <adminserver hostalias="node2" />
  </admin>
</services>
ENDER
    return app
  end
  
def generate_app2(cmd, service_name)
    app=<<ENDER
<?xml version="1.0" encoding="utf-8" ?>
<services version="1.0">

  <admin version="2.0">
    <adminserver hostalias="node1" />
    <slobroks>
      <slobrok hostalias="node1"/>
      <slobrok hostalias="node1"/>
    </slobroks>
  </admin>

  <service id="simpleapp" name="#{service_name}" command="#{cmd}" version="1.0">
    <node hostalias="node1" />
  </service>
  <container id="stateless" version="1.0">
      <search/>
      <http>
          <server id="qrs" port="#{Environment.instance.vespa_web_service_port}"/>
      </http>
      <nodes>
        <node hostalias="node1"/>
      </nodes>
  </container>
</services>
ENDER
    return app
  end

  def deploy_with_tenant(app, tenant, application_name, params={})
    params = params.merge({:tenant => tenant}).merge({:application_name => application_name})
    deploy(app, nil, nil, params)
  end

  def deploy_app_with_tenant(hostname, logserver_port)
    app = multitenant_app(hostname, logserver_port)
    params = {:tenant => @tenant, :application_name => @application_name, :instance => @instance, :hosts_to_use => [hostname]}
    deploy_app(app, params)
  end

  def assert_config(rpcport, hostname=@configserver)
    config = get_config("cloud.config.log.logd", "admin", hostname)
    logserver = config["logserver"]
    assert_equal(rpcport, logserver["rpcport"].to_i)
  end

  def get_config(configName, configId, hostname, instance_name="default")
    get_config_v2_assert_200(hostname, @tenant_name, @application_name, instance_name, configName, configId)
  end

  def assert_config_output_in_log(regexp)
    assert_log_matches(regexp, 30)
  end

  def teardown
    delete_tenant_and_its_applications(@hostname, TENANT_A)
    delete_tenant_and_its_applications(@hostname, TENANT_B)
    stop
  end

end
