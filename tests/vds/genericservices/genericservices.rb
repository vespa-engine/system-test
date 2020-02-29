require 'vds_test'

class GenericServices < VdsTest

  def nightly?
    true
  end

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
    sleep 10

    hostname = `hostname`.strip
    iostat_regexp = Regexp.compile("iostat\\s.*Device:            tps")
    iostat2_regexp = Regexp.compile("iostat2\\s.*Device:            tps")
    vmstat_regexp= Regexp.compile("vmstat\\s.*\\s.*procs -----------memory----------")
    vmstat2_regexp= Regexp.compile("vmstat2\\s.*\\s.*procs -----------memory----------")

    assert_log_matches(iostat_regexp)
    assert_log_not_matches(iostat2_regexp)
    assert_log_matches(vmstat_regexp)
    assert_log_matches(vmstat2_regexp) # Second service on node 1 => host2

    assert_ps_output_exists("node1", "iostat", "iostat 100")
    assert_ps_output_exists("node2", "iostat", "iostat 100")
    assert_ps_output_exists("node3", "iostat", "iostat 100")

    assert_ps_output_exists("node1", "vmstat", "vmstat 100")
    assert_ps_output_does_not_exists("node2", "vmstat", "vmstat 100")
    assert_ps_output_exists("node3", "vmstat", "vmstat 100")

    #stop
    vespa.hostalias["node1"].execute("vespa-stop-services")
    sleep 5
    assert_ps_output_does_not_exists("node1", "iostat", "iostat 100")
    assert_ps_output_does_not_exists("node1", "vmstat", "vmstat 100")

    #start
    vespa.hostalias["node1"].execute("vespa-start-services")
    wait_until_ready
    assert_ps_output_exists("node1", "iostat", "iostat 100")
    assert_ps_output_exists("node1", "vmstat", "vmstat 100")
    assert_equal(2, assert_log_matches(iostat_regexp))
    assert_equal(2, assert_log_matches(vmstat_regexp))

    # kill the processes and check that they are restarted
    vespa.hostalias["node1"].execute("killall iostat")
    vespa.hostalias["node1"].execute("killall vmstat")
    sleep 10
    assert_ps_output_exists("node1", "iostat", "iostat 100")
    assert_ps_output_exists("node1", "vmstat", "vmstat 100")

    #stop
    vespa.hostalias["node1"].execute("vespa-stop-services")
    assert_ps_output_does_not_exists("node1", "iostat", "iostat 100")
  end

  def assert_ps_output_exists(node, process_name, expected_output)
    assert(vespa.hostalias[node].execute("ps auxwww | grep #{process_name} | grep -v grep", :exceptiononfailure => false) =~ Regexp.compile(expected_output))
  end

  def assert_ps_output_does_not_exists(node, process_name, expected_output)
    assert(vespa.hostalias[node].execute("ps auxwww | grep #{process_name} | grep -v grep", :exceptiononfailure => false) !~ Regexp.compile(expected_output))
  end

  def teardown
    stop
  end

end
