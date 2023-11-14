# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'search_test'
require 'app_generator/cloudconfig_app'
require 'environment'

class ConfigServer < CloudConfigTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    1000
  end

  def setup
    set_description("Tests configserver functionality.")
    set_owner("musum")
    @configserver = nil
  end

  def test_deploy_no_activate_restart
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))

    # sanity check for field from sd
    assert_match("age", get_document_config())

    # deploy a new app, but do not activate config
    deploy_app(SearchApp.new.sd(selfdir+"sd-extend/banana.sd"), {:no_activate => true, :skip_create_model => true})

    # restart configserver and keep zookeeper data
    restart_config_server(vespa.configservers["0"], :keep_zookeeper_data => true)

    # we should still run with the same application as before deploy,
    # since we did not activate config, so similarfruits should not be there
    assert_match("age", get_document_config())
    assert_no_match("similarfruits", get_document_config())
  end

  # Tests that there are no zookeeper issues when deploying twice in a row
  # (we have had issues with first deploy working and the next one not, due
  # to programming errors when writing to zookeeper, which is hard to test in
  # unit tests)
  def test_deploy_twice
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
  end

  # Tests that deploying and activating session 1, then deploying many more
  # applications (without preparing and activating), stopping the server will
  # still load session 1 after restart. Dependent on the number of applicaations
  # we retain when deploying (currently 10)
  def test_deploy_many_times
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))

    # sanity check for field from sd
    assert_match("age", get_document_config())
    
    (0..15).each do |i|
      # deploy a new app, but do not activate config
      deploy_app(SearchApp.new.sd(selfdir+"sd-extend/banana.sd"), {:no_activate => true, :skip_create_model => true})
    end

    # restart configserver and keep zookeeper data
    restart_config_server(vespa.configservers["0"], :keep_zookeeper_data => true)

    # we should still run with the same application as before all the 15 deployments
    # since we did not activate config, so similarfruits should not be there
    assert_match("age", get_document_config())
    assert_no_match("similarfruits", get_document_config())
  end

  # Check that an application with an error is skipped and that another application works just
  # fine afterwards
  def test_isolation_between_applications_invalid_data_in_file_system
    deploy_app(CloudconfigApp.new)
    assert_deploy_app_fail(SearchApp.new.sd(selfdir + "sd/invalid_sd_construct.sd"))
    vespa.configservers["0"].stop_configserver({:keep_everything => true})
    vespa.configservers["0"].start_configserver
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
    start
  end

  # Check that there is maximum one lock file for { configserver, container, container-clustercontroller }
  # when restarting many times.
  # See ticket http://bug.corp.yahoo.com/7072930
  def test_stop_should_not_leave_lockfiles
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
    assert(get_configserver_zookeeper_lock_files_count <= 1, get_configserver_zookeeper_lock_files)
    start
    # 2 services create zookeeper lock files: container and container-clustercontroller
    assert(get_services_zookeeper_lock_files_count <= 2, get_services_zookeeper_lock_files)
    vespa.stop_base
    vespa.start_base
    wait_until_ready
    assert(get_services_zookeeper_lock_files_count <= 2, get_services_zookeeper_lock_files)
    vespa.configservers["0"].stop_configserver({:keep_everything => true})
    vespa.configservers["0"].start_configserver
    vespa.configservers["0"].ping_configserver
    assert(get_configserver_zookeeper_lock_files_count <= 1, get_configserver_zookeeper_lock_files)
  end

  def test_redeploy_applications_on_upgrade
    set_expected_logged(/Redeploying default.default failed, will retry/)

    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
    assert_log_matches("Session 2 activated successfully", 1)
    assert_log_not_matches("Session 3 activated successfully")
    restart_config_server_and_reset_version
    vespa.configservers["0"].ping_configserver
    sleep 5
    assert_log_matches("Session 3 activated successfully", 1)
    assert_health_status_for_config_server("up")

    # Manipulate version of deployed application, to simulate an upgrade of vespa
    # Health status should be 'up' when this is the case
    zk_path = "/config/v2/tenants/default/sessions/3/version"
    # NOTE: Needs to be a version number with same major version as the deployed version
    vespa.configservers["0"].execute("echo \"set #{zk_path} 7.999.999\" | vespa-zkcli")
    vespa.configservers["0"].stop_configserver({:keep_everything => true})
    vespa.configservers["0"].start_configserver
    vespa.configservers["0"].ping_configserver
    assert_log_not_matches("Unknown Vespa version '6.0.0'")
    # Clean up everything
    restart_config_server(vespa.configservers["0"])

    # Manipulate deployed application so that application package is invalid when restarting config server
    # Health status should be 'initializing', not 'up' when this is the case
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
    services_xml = "#{Environment.instance.vespa_home}/var/db/vespa/config_server/serverdb/tenants/default/sessions/2/services.xml"
    vespa.configservers["0"].execute("cp #{services_xml} #{services_xml}.bak")
    vespa.configservers["0"].execute("echo 'invalid xml' >> #{services_xml}")
    restart_config_server_and_reset_version
    wait_for_atleast_log_matches("Redeploying default.default failed, will retry", 1, 60)
    begin
      assert_health_status_for_config_server("initializing")
    rescue
      puts "Could not get health status, http server not up, as expected"
    end
 
    puts "Fix broken app"
    vespa.configservers["0"].execute("vespa-logctl -c configserver:com.yahoo.vespa.config.server.ConfigServerBootstrap debug=on", :exceptiononfailure => false)
    vespa.configservers["0"].execute("cp #{services_xml}.bak #{services_xml}") # Go back to original services.xml, server should come up again
    wait_for_atleast_log_matches("All applications redeployed successfully", 1, 240)
    assert_health_status_for_config_server("up")
  end

  def test_wait_for_config_converge
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
    start
    wait_for_config_converge(60)
  end

  # When canReturnEmptySentinelConfig is true and app has been deleted an
  # empty sentinel config should be returned and services stopped
  def test_empty_sentinel_config_when_app_is_deleted
    deploy_app(CloudconfigApp.new)
    node = vespa.configservers["0"]

    override = <<ENDER
<config name="cloud.config.configserver">
  <canReturnEmptySentinelConfig>true</canReturnEmptySentinelConfig>
</config>
ENDER
    config_file = Environment.instance.vespa_home + "/conf/configserver-app/configserver-config.xml"
    node.execute("echo '#{override}' > #{config_file}")
    restart_config_server(node, :keep_zookeeper_data => true)
    deploy_app(CloudconfigApp.new)
    start
    wait_for_logserver_state{ logserver_running }
    delete_application_v2(node.hostname, "default", "default")

    # Check that config is empty and that logserver service is no longer running
    wait_for_logserver_state{ logserver_not_running }
    assert_equal(0, getvespaconfig("cloud.config.sentinel", "client", nil, node.hostname, 19070)['service'].size)
  end

  def logserver_running
    "RUNNING" == vespa.logserver.get_state.strip
  end

  def logserver_not_running
    ! logserver_running
  end

  def wait_for_logserver_state(&block)
    i = 0
    loop do
      break if yield or i > 70
      i = i + 1
      sleep 1
    end
    assert(yield)
  end

  def wait_for_config_converge(timeout)
    hostname = vespa.configservers["0"].hostname
    url = "http://#{hostname}:#{DEFAULT_SERVER_HTTPPORT}/application/v2/tenant/default/application/default/environment/prod/region/default/instance/default/serviceconverge?timeout=#{timeout}"
    response = http_request_get(URI(url), {})
    assert_equal(200, response.code.to_i)
  end

  # Remove the stored vespa version, config server will redeploy applications when it comes up
  # since there will now be an upgrade of the config server's version
  def restart_config_server_and_reset_version
    current_version = vespa.configservers["0"].execute("vespa-print-default version").strip
    previous_version = current_version.gsub(/(\d+)\.(\d+)\.(\d+)/, '\1.\2.0') # Same major.minor version but micro version 0 => always an earlier version
    vespa.configservers["0"].execute("echo \"set /config/v2/vespa_version #{previous_version}\" | vespa-zkcli", :exceptiononfailure => false)
    vespa.configservers["0"].stop_configserver({:keep_everything => true})
    vespa.configservers["0"].execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/config_server/serverdb/vespa_version")
    vespa.configservers["0"].start_configserver
  end

  def assert_health_status_for_config_server(expected_status)
    hostname = vespa.configservers["0"].hostname
    url = "http://#{hostname}:#{DEFAULT_SERVER_HTTPPORT}/state/v1/health"
    response = http_request_get(URI(url), {:open_timeout => 5.0, :read_timeout => 5.0})
    assert_equal(200, response.code.to_i)
    assert_equal(expected_status, JSON.parse(response.body)["status"]["code"])
  end

  def get_configserver_zookeeper_lock_files_count
    run_command("ls #{Environment.instance.vespa_home}/logs/vespa/zookeeper.configserver*lck | wc -l").to_i
  end

  def get_configserver_zookeeper_lock_files
    run_command("ls #{Environment.instance.vespa_home}/logs/vespa/zookeeper.configserver*lck")
  end

  def get_services_zookeeper_lock_files_count
    run_command("ls #{Environment.instance.vespa_home}/logs/vespa/zookeeper*lck | grep -v configserver | wc -l").to_i
  end

  def get_services_zookeeper_lock_files
    run_command("ls #{Environment.instance.vespa_home}/logs/vespa/zookeeper*lck | grep -v configserver")
  end

  def run_command(command)
    vespa.adminserver.execute(command, :exceptiononfailure => false).strip
  end

  # Check that setting jute maxbuffer in config override works (checks that Java system property is set)
  def test_jute_maxbuffer
    deploy_app(CloudconfigApp.new)
    @configserver = vespa.configservers["0"]

    @configserver.stop_configserver()
    override =<<ENDER
  <config name="cloud.config.zookeeper-server">
      <juteMaxBuffer>12345</juteMaxBuffer>
  </config>
ENDER
   
    add_xml_file_to_configserver_app(@configserver, override, "jutemaxbuffer.xml")
    @configserver.start_configserver
    @configserver.ping_configserver

    pid = @configserver.get_configserver_pid

    case vespa.adminserver.execute("whoami").strip
    when "root"
      sudo_cmd = "/usr/bin/sudo -u #{Environment.instance.vespa_user}"
    else
      sudo_cmd = ""
    end
    command = "#{sudo_cmd} jinfo -sysprops #{pid.to_s} 2>&1 | grep jute.maxbuffer"
    assert_equal('jute.maxbuffer=12345', vespa.adminserver.execute(command).strip)

    remove_xml_file_from_configserver_app(@configserver, override, "jutemaxbuffer.xml")
  end

  def copy_app_and_write_large_file(app_dir, tmpdir, large_file_size)
    system("mkdir -p " + tmpdir + app_dir)
    system("cp -r #{selfdir}#{app_dir} #{tmpdir}")
    write_file(tmpdir + app_dir + "large-file", large_file_size)
    tmpdir + app_dir
  end

  def write_file(file, size)
    File.open(file, 'wb') do |f|
      size.times { f.write("a") }
    end
  end

  # Check that we can run configserver on a different port.
  def ignored_test_custom_rpc_port
    set_port_configserver_rpc(vespa.nodeproxies.values.first, 12345)
    deploy_app(SearchApp.new.sd(selfdir+"sd/banana.sd"))
    start
    assert_match("age", get_document_config(12345))
  end

  def get_document_config(port=19070)
    vespa.adminserver.execute("vespa-get-config -n document.config.documentmanager -w 60 -p #{port} | grep field | grep name")
  end

  def teardown
    set_port_configserver_rpc(vespa.nodeproxies.values.first)
    stop
  end
end
