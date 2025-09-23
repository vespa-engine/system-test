# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'app_generator/search_app'
require 'environment'

class VespaConfigSources < ConfigTest

  def setup
    set_owner("musum")
    set_description("Tests getting config sources from vespa-print-default")
    @node = vespa.nodeproxies.first[1]
  end

  def test_vespa_config_sources_from_defaults
    app_gen = SearchApp.new.sd(SEARCH_DATA+"music.sd")
    deploy_app(app_gen)
    @node = vespa.adminserver
    @hostname = @node.hostname

    assert_equal("tcp/" + @hostname + ":19070", print_default("configservers_rpc"))
    assert_equal("19070", print_default("configserver_rpc_port"))

    set_port_configserver_rpc(@node)
    assert_equal("http://#{@hostname}:19071/", print_default("configservers_http"))
  end

  def print_default(option, noexception=false)
    command = Environment.instance.vespa_home + "/bin/vespa-print-default #{option} 2>/dev/null"
    params = noexception ? {:exitcode => true, :exceptiononfailure => false} : {}
    @node.execute(command, params).strip
  end


end
