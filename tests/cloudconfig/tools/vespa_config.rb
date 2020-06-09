require 'cloudconfig_test'
require 'app_generator/search_app'
require 'environment'

class VespaConfig < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Test vespa-config.pl")
    @node = vespa.nodeproxies.first[1]
  end

  def nigthly?
    true
  end

  def test_vespa_config
    app_gen = SearchApp.new.sd(SEARCH_DATA+"music.sd")
    deploy_app(app_gen)
    @node = vespa.adminserver
    @hostname = @node.hostname

    run_configsource_test
    run_configserverport_test
    run_zkstring_test
    run_empty_port_test
  end

  def run_configsource_test
    output = call_vespa_config_script("-configsources")
    assert_equal("tcp/" + @hostname + ":19070", output.strip)
  end

  def run_configserverport_test
    output = call_vespa_config_script("-configserverport")
    assert_equal("19070", output.strip)
  end

  def verify_output_ok
    verify_output(0, "yes")
  end

  def verify_output_fail
    verify_output(1, "no")
  end

  def verify_output(expected_exit_code, expected_message)
    (exit_code, output) = call_vespa_config_script("-isthisaconfigserver", true)
    assert_equal(expected_exit_code, exit_code.to_i)
    assert_equal(expected_message, output.strip)
  end

  def run_zkstring_test
    output = call_vespa_config_script("-zkstring")
    assert_equal(@hostname + ":2181", output.strip)
  end

  def run_empty_port_test
    set_port_configserver_rpc(@node)
    output = call_vespa_config_script("-confighttpsources")
    assert_equal("http://#{@hostname}:19071", output.strip)
  end

  def call_vespa_config_script(option, noexception=false)
    command = Environment.instance.vespa_home + "/libexec/vespa/vespa-config.pl #{option} 2>/dev/null"
    if noexception
      @node.execute(command, {:exitcode => true, :exceptiononfailure => false})
    else
      @node.execute(command)
    end
  end

  def teardown
    stop
  end

end
