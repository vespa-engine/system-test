require 'cloudconfig_test'
require 'app_generator/search_app'
require 'environment'

class VespaModelInspect < CloudConfigTest
  @@modelinspect = "#{Environment.instance.vespa_home}/bin/vespa-model-inspect 2>/dev/null"

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    set_owner("musum")
    set_description("Tests vespa-model-inspect")

    app_gen = SearchApp.new.sd(SEARCH_DATA+"music.sd").
      num_hosts(2).
      slobrok("node2")
    deploy_app(app_gen)
    @node1 = vespa.adminserver
    @node2 = vespa.slobrok["0"]
    start
  end

  def nigthly?
    true
  end

  def test_vespamodelinspect
    assert_output(@node1)
    assert_output(@node2)
  end

  def assert_output(node)
    services = <<EOS;
config-sentinel
configproxy
configserver
container
container-clustercontroller
distributor
logd
logserver
metricsproxy-container
searchnode
slobrok
storagenode
transactionlogserver
EOS
    (exitcode, out) = execute(node, "#{@@modelinspect} services")
    assert_equal(exitcode, 0)
    assert_equal(services, out)
  end

  def teardown
    stop
  end

end
