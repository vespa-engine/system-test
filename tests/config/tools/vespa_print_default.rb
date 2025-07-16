# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'app_generator/search_app'
require 'environment'

class VespaPrintDefault < ConfigTest

  def setup
    set_owner("musum")
    set_description("Tests vespa-print-default")
  end

  def test_vespa_print_default
    app_gen = SearchApp.new.sd(SEARCH_DATA+"music.sd")
    deploy_app(app_gen)
    @node = vespa.adminserver
    @hostname = @node.hostname

    expected = <<EOF
VESPA_HOME = '/opt/vespa'
underVespaHome(foo) = '/opt/vespa/foo'
VESPA_USER = 'vespa'
VESPA_HOSTNAME = '#{@hostname}'
web service port = #{Environment.instance.vespa_web_service_port}
VESPA_PORT_BASE = 19000
config server rpc port = 19070
config server host 1 = '#{@hostname}'
config server rest URL 1 = 'http://#{@hostname}:19071/'
config proxy RPC addr = 'tcp/localhost:19090'
sanitizers = 'none'
vespa version = '#{vespa.vespa_version}'
EOF

    assert_equal(expected, print_default("everything"))
  end

  def print_default(option, noexception=false)
    command = Environment.instance.vespa_home + "/bin/vespa-print-default #{option} 2>/dev/null"
    @node.execute(command)
  end

  def teardown
    stop
  end

end
