# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'executor'
require 'default_env_file'
require 'uri'

# A base class for a singleton providing the default environment in
# which to run tests.  To access, use "Environment.instance" before
# fields and methods.
#
# If the environment needs to be customized when running tests,
# this can be replaced by an environment-specific implementation.
class EnvironmentBase
  attr_reader :vespa_home, :vespa_web_service_port, :vespa_user, :tmp_dir, :path_env_variable, :additional_start_base_commands, :maven_snapshot_url
  attr_reader :vespa_hostname, :vespa_short_hostname

  def initialize(default_vespa_home, default_vespa_user, default_vespa_web_service_port)
    if ENV.has_key?('VESPA_HOME')
      @vespa_home = ENV['VESPA_HOME']
    else
      @vespa_home = default_vespa_home
    end

    if ENV.has_key?('VESPA_WEB_SERVICE_PORT')
      @vespa_web_service_port = ENV['VESPA_WEB_SERVICE_PORT'].to_i
    else
      @vespa_web_service_port = default_vespa_web_service_port
    end

    if ENV.has_key?('VESPA_USER')
      @vespa_user = ENV['VESPA_USER']
    else
      @vespa_user = default_vespa_user
    end

    if ENV.has_key?('VESPA_HOSTNAME')
      @vespa_hostname = ENV['VESPA_HOSTNAME']
    else
      @vespa_hostname = `hostname`.chomp
    end

    hostname_components = @vespa_hostname.split(".")
    if hostname_components.size > 0
      if hostname_components.size > 1 && hostname_components[1] =~ /^\d+$/
        @vespa_short_hostname = hostname_components.first(2).join(".")
      else
        @vespa_short_hostname = hostname_components[0]
      end
    else
      @vespa_short_hostname = @vespa_hostname
    end
    @executor = Executor.new(@vespa_short_hostname)

    if File.exists?(@vespa_home)
      @tmp_dir = @vespa_home + "/tmp"
    else
      @tmp_dir = "/tmp" # When running unit tests with no Vespa installed
    end

    @path_env_variable = "#{@vespa_home}/bin:/opt/vespa-deps/bin"
    @additional_start_base_commands = ""
    @maven_snapshot_url = nil # TODO
    @default_env_file = DefaultEnvFile.new(@vespa_home)
  end

  def set_addr_configserver(testcase, config_hostnames)
    configservers = config_hostnames.join(",")
    @default_env_file.set("VESPA_CONFIGSERVERS", configservers)
    ENV["VESPA_CONFIGSERVERS"] = configservers
  end

  def set_port_configserver_rpc(testcase, port=nil)
    @default_env_file.set("VESPA_CONFIGSERVER_RPC_PORT", port)
    ENV["VESPA_CONFIGSERVER_RPC_PORT"] = port
  end

  def start_configserver(testcase)
    @executor.execute("#{@vespa_home}/bin/vespa-start-configserver", testcase)
  end

  def stop_configserver(testcase)
    @executor.execute("#{@vespa_home}/bin/vespa-stop-configserver", testcase)
  end

  def reset_configserver(configserver)
    # TODO
  end

  def reset_environment(node)
    node.reset_environment_setting
  end

  def backup_environment_setting(force)
    @default_env_file.backup_original(force)
  end

  def reset_environment_setting(testcase)
    @default_env_file.restore_original
  end

  # Returns the host name of a host from which standard test data can be downloaded
  # +hostname+:: The host name which will download test data
  def testdata_server(hostname)
    ENV.has_key?('VESPA_TESTDATA_SERVER') ? ENV['VESPA_TESTDATA_SERVER'] : hostname
  end

  # Returns the URL of the test data server
  # +hostname+:: The host name which will download test data
  def testdata_url(hostname)
    URI(ENV.has_key?('VESPA_TESTDATA_URL') ? ENV['VESPA_TESTDATA_URL'] : "https://#{testdata_server(hostname)}:443")
  end

  def override_environment_setting(testcase, name, value)
    @default_env_file.set(name, value)
  end

end
