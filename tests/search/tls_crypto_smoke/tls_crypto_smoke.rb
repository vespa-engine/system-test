# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class TlsCryptoSmokeTest < IndexedSearchTest

  def initialize(*args)
    super(*args)
  end

  def can_share_configservers?(method_name=nil)
    return false
  end

  def verify_endpoint_is_running_with_tls(hostname, port)
    puts "Verifying #{hostname}:#{port} is running TLS"
    files = @tls_config['files']
    # The empty echo is to ensure that we don't have the test case somehow attached to stdin,
    # as s_client will otherwise hang until EOF...!
    # We assume key/cert files are in the same location across all test nodes.
    # Add -debug to args to see hex dumps of all packets sent and received
    vespa.adminserver.execute("echo -n '' | openssl s_client -connect #{hostname}:#{port} " +
                              "-CAfile #{files['ca-certificates']} -cert #{files['certificates']} " +
                              "-key #{files['private-key']} -tls1_2 -verify_return_error",
                              :exceptiononfailure => true)
    # If the above doesn't fail, we're all good
    puts "Looks that way!"
  end

  def content_node
    vespa.storage['search'].storage['0']
  end

  def config_server
    vespa.configservers['0']
  end

  def verify_basic_api_functionality
    # Basic feeding and searching must work as expected
    feed(:file => SEARCH_DATA + 'music.10.xml', :timeout => 240)
    wait_for_hitcount('query=sddocname:music', 10)

    # TODO test document API, tooling
  end

  def verify_backend_servers_in_cpp_and_java_support_tls
    # For simplicity, we assume it's sufficient to sample one RPC endpoint for every
    # implementation language.

    # Configserver RPC should be available via TLS
    verify_endpoint_is_running_with_tls(config_server.name, config_server.port_configserver_rpc)
    # Sample a C++ backend to ensure it speaks TLS as well
    verify_endpoint_is_running_with_tls(content_node.name, content_node.ports_by_tag['rpc'])
  end

  def env_line_to_key_value(e)
    if e !~ /([^=]+)=(.*)/
      raise "Not a key-value mapping string: #{e}"
    end
    [$~[1], $~[2]]
  end

  def test_vespa_processes_run_with_tls_in_system_test_environment
    set_description('Test that backend servers in C++ and Java can be launched ' +
                    'with TLS and mixed mode enabled')

    deploy_app(SearchApp.new.sd(SEARCH_DATA + 'music.sd'))
    start

    remote_env = content_node.execute('env | grep VESPA', :noecho => true).each_line.map{ |e| env_line_to_key_value(e) }.to_h
    puts "Test runner environment:"
    remote_env.each { |k,v| puts "  #{k} -> #{v}" }
    puts

    cfg_file = remote_env['VESPA_TLS_CONFIG_FILE']
    if cfg_file.nil? or cfg_file.empty?
      flunk('Test is not configured to run with TLS enabled')
    end
    puts "Found active TLS config environment variable: #{cfg_file}"
    @tls_config = JSON.parse(content_node.readfile(cfg_file))

    verify_basic_api_functionality
    verify_backend_servers_in_cpp_and_java_support_tls
  end

  # TODO test both plaintext_client and tls_client mixed modes
  # TODO verify that we _can't_ connect without client cert
  # TODO verify that we can connect with plaintext mode as well

  def teardown
    stop
  end

end

