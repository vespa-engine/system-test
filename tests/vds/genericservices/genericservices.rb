# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class GenericServicesTest < VdsTest

  def initialize(*args)
      super(*args)
      @num_hosts = 3
  end

  def setup
    set_owner("musum")
  end

  def test_generic_services_multinode
    deploy(selfdir+"app_multinode")
    start

    vmstat_regexp = Regexp.compile("vmstat\\s.*\\s.*procs -----------memory----------")
    vmstat2_regexp = Regexp.compile("vmstat2\\s.*\\s.*procs -----------memory----------")

    assert_log_matches(vmstat_regexp)
    assert_log_matches(vmstat2_regexp) # Second service on node 1 => host2

    assert_ps_output_exists("node1", "vmstat", "vmstat 100")
    assert_ps_output_does_not_exists("node2", "vmstat", "vmstat 100")
    assert_ps_output_exists("node3", "vmstat", "vmstat 100")

    vespa.hostalias["node1"].execute("vespa-stop-services")
    assert_ps_output_does_not_exists("node1", "vmstat", "vmstat 100")

    vespa.hostalias["node1"].execute("vespa-start-services")
    wait_until_ready
    assert_ps_output_exists("node1", "vmstat", "vmstat 100")
    # Services on 2 nodes, vmstat restarted on 1 node, so should be 3 log messages matching
    wait_for_atleast_log_matches(vmstat_regexp, 3, 60, {:use_logarchive => true})

    # kill the processes and check that they are restarted
    vespa.hostalias["node1"].execute("pkill --signal SIGTERM vmstat")
    wait_until_ps_output_exists("node1", "vmstat", "vmstat 100")

    vespa.hostalias["node1"].execute("vespa-stop-services")
    assert_ps_output_does_not_exists("node1", "vmstat", "vmstat 100")
  end

  def assert_ps_output_exists(node, process_name, expected_output)
    assert(ps_output_exists(node, process_name) =~ Regexp.compile(expected_output))
  end

  def wait_until_ps_output_exists(node, process_name, expected_output)
    count = 0
    loop do
      puts "loop, count=#{count}"
      output = ps_output_exists(node, process_name)
      break if output =~ Regexp.compile(expected_output) || count > 10
      count = count + 1
      sleep 1
    end
    assert_ps_output_exists(node, process_name, expected_output)
  end

  def ps_output_exists(node, process_name)
     vespa.hostalias[node].execute("ps auxwww | grep #{process_name} | grep -v grep", :exceptiononfailure => false)
  end

  def assert_ps_output_does_not_exists(node, process_name, expected_output)
    assert(vespa.hostalias[node].execute("ps auxwww | grep #{process_name} | grep -v grep", :exceptiononfailure => false) !~ Regexp.compile(expected_output))
  end

  def teardown
    stop
  end

end
