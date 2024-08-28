# Copyright Vespa.ai. All rights reserved.
require 'cloudconfig_test'
require 'app_generator/search_app'
require 'environment'

class VespaModelInspect < CloudConfigTest
  @@modelinspect = "#{Environment.instance.vespa_home}/bin/vespa-model-inspect"

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    set_owner("musum")
    set_description("Tests vespa-model-inspect")

    app = SearchApp.new.sd(SEARCH_DATA+"music.sd")
    if @num_hosts == 2
      app = app.num_hosts(@num_hosts).
              slobrok("node2")
    end
    deploy_app(app)
    @node1 = vespa.adminserver
    @node2 = vespa.slobrok["0"] if @num_hosts == 2
    start
  end

  def test_vespamodelinspect
    assert_output(@node1)
    assert_output(@node2) if @num_hosts == 2
  end

  def assert_output(node)
    expected_services = <<EOS;
config-sentinel
configproxy
configserver
container
container-clustercontroller
distributor
logd
logserver
logserver-container
metricsproxy-container
searchnode
slobrok
storagenode
EOS
    assert_exec_output(node, "#{@@modelinspect} services 2>/dev/null", 0, expected_services)
  end

  def teardown
    stop
  end

end
