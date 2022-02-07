# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'environment'

class Namespace < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Test that using namespace in config definition and services config works.")
    @classpath = "#{Environment.instance.vespa_home}/lib/jars/config.jar"
  end

  def initialize(*args)
    super(*args)
  end

  def generate_app(cmd, cmd2)
    app=<<ENDER
<?xml version="1.0" encoding="utf-8" ?>
<services version="1.0">

  <admin version="2.0">
    <adminserver hostalias="node1" />
  </admin>

  <service id="simpleapp" name="simpleapp" command="#{cmd}" version="1.0">
    <config name="bar.simple">
      <foo>SimpleApp</foo>
    </config>
    <node hostalias="node0" />
  </service>

  <service id="simpleapp2" name="simpleapp2" command="#{cmd2}" version="1.0">
    <config name="bar.baz.extra">
      <quux>SimpleApp2</quux>
    </config>
    <!-- Tests namespace with digit too -->
    <config name="bar2.baz_foo.simple">
      <foo>SimpleApp2</foo>
    </config>
    <node hostalias="node0" />
  </service>

</services>
ENDER
    return app
  end

  def test_config
    add_bundle_dir(File.expand_path(selfdir + "simplebundle"), "simplebundle")
    add_bundle_dir(File.expand_path(selfdir + "simplebundle2"), "simplebundle2")
    cmd = "java -cp #{@classpath} -jar simplebundle-1.0-deploy.jar"
    cmd2 = "java -cp #{@classpath} -jar simplebundle2-1.0-deploy.jar"
    app = generate_app("cd " + dirs.tmpdir + "/bundles; #{cmd}", "cd " + dirs.tmpdir + "/bundles; #{cmd2}")
    deploy_generated(app)
    start
    sleep 10
    assert_log_matches("foo: SimpleApp", 5)
    assert_log_matches("foo: SimpleApp2", 5)
    assert_log_matches("quux: SimpleApp2", 5)
  end

  def teardown
    stop
  end

end
