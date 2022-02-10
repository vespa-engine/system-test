# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'cloudconfig_test'
require 'set'
require 'environment'

class SuperModel < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Tests subscribing to supermodel")
  end

  def test_subscribe_to_supermodel
    add_expected_logged(/got addPeer with .* check config consistency/)
    add_expected_logged(/configured partner list does not contain peer/)
    add_expected_logged(/Unable to send default state/)

    add_bundle("supermodelbundle")
    service_name = "supermodelclient"
    classpath = "#{Environment.instance.vespa_home}/lib/jars/config.jar"
    cmd = "cd #{dirs.tmpdir}/bundles; VESPA_CONFIG_ID=#{service_name} java -cp #{classpath}:supermodelbundle-1.0-deploy.jar com.yahoo.supermodelclient.SuperModelClient"
    puts "CMD=#{cmd}"

    # Add a jdisc cluster to the app and check that it is included in config
    app = generate_app(cmd, service_name)
    deploy_generated(app)
    start
    assert_config_output_in_log("default,default:prod:default:default,false,0")
  end

  def add_bundle(name)
    clear_bundles
    add_bundle_dir(File.expand_path(selfdir+name), name)
  end

def generate_app(cmd, service_name)
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
      <document-api />
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

  def assert_config_output_in_log(regexp)
    assert_log_matches(regexp, 30)
  end

  def teardown
    stop
  end

end
