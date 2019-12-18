require 'vds_test'

class GenericServices < VdsTest

  def nightly?
    true
  end

  def initialize(*args)
      super(*args)
      @num_hosts = 5
  end

  def setup
    set_owner("musum")
  end

  def test_generic_services_multinode
    deploy(selfdir+"app_multinode")
    start
    sleep 5
    assert_log_matches(Regexp.compile("pinglocalhost\\s.*icmp_seq"))
    assert_log_not_matches(Regexp.compile("pinglocalhost2\\s.*icmp_seq"))
    assert_log_matches(Regexp.compile("pinglo\\s.*icmp_seq"))
    assert_log_matches(Regexp.compile("pinglo2\\s.*icmp_seq"))

    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") =~ /ping localhost/)
    assert(vespa.hostalias["node2"].execute("ps auxwww | grep ping") =~ /ping localhost/)
    assert(vespa.hostalias["node3"].execute("ps auxwww | grep ping") !~ /ping localhost/)
    assert(vespa.hostalias["node4"].execute("ps auxwww | grep ping") !~ /ping localhost/)
    assert(vespa.hostalias["node5"].execute("ps auxwww | grep ping") !~ /ping localhost/)

    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") =~ /ping 127/)
    assert(vespa.hostalias["node2"].execute("ps auxwww | grep ping") !~ /ping 127/)
    assert(vespa.hostalias["node3"].execute("ps auxwww | grep ping") =~ /ping 127/)
    assert(vespa.hostalias["node4"].execute("ps auxwww | grep ping") =~ /ping 127/)
    assert(vespa.hostalias["node5"].execute("ps auxwww | grep ping") =~ /ping 127/)
    #stop
    vespa.hostalias["node1"].execute("vespa-stop-services")
    sleep 5
    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") !~ /ping localhost/)
    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") !~ /ping 127/)
    assert(assert_log_matches(Regexp.compile("pinglocalhost\\s.*bytes of data"))==1)
    assert(assert_log_matches(Regexp.compile("pinglo\\s.*bytes of data"))==1)

    #start
    vespa.hostalias["node1"].execute("vespa-start-services")
    wait_until_ready
    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") =~ /ping localhost/)
    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") =~ /ping 127/)
    assert(assert_log_matches(Regexp.compile("pinglocalhost\\s.*bytes of data"))==2)
    assert(assert_log_matches(Regexp.compile("pinglo\\s.*bytes of data"))==2)

    # kill the processes and check that they are restarted
    vespa.hostalias["node1"].execute("killall ping")
    sleep 10
    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") =~ /ping localhost/)
    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") =~ /ping 127/)
    assert(assert_log_matches(Regexp.compile("pinglocalhost\\s.*bytes of data"))==3)
    assert(assert_log_matches(Regexp.compile("pinglo\\s.*bytes of data"))==3)

    #stop
    vespa.hostalias["node1"].execute("vespa-stop-services")
    assert(vespa.hostalias["node1"].execute("ps auxwww | grep ping") !~ /ping localhost/)
  end

  def teardown
    stop
  end

end
