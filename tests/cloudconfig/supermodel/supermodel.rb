# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

    # Add a jdisc cluster to the app and check that it is included in config
    app = generate_app()
    deploy_generated(app)
    start

    classpath = "#{Environment.instance.vespa_home}/lib/jars/config.jar"
    env_variables = "VESPA_CONFIG_ID=supermodelclient VESPA_LOG_TARGET=file:/opt/vespa/logs/vespa/vespa.log"
    cmd = "cd #{dirs.tmpdir}/bundles; #{env_variables}; java -cp #{classpath}:supermodelbundle-1.0-deploy.jar com.yahoo.supermodelclient.SuperModelClient"
    output = vespa.adminserver.execute(cmd)
    assert_match("default,default:prod:default:default,false,0", output)
  end

  def add_bundle(name)
    clear_bundles
    add_bundle_dir(File.expand_path(selfdir+name), name)
  end

def generate_app()
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

  def teardown
    stop
  end

end
