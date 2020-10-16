# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class SigBusHandler < IndexedSearchTest

  def setup
    set_owner("toregge")
    set_description("Test basic sigbus handling")
    @valgrind = false
    @valgrind_opt = nil
    @coredump_sleep = 30
    @datadir = "#{Environment.instance.vespa_home}/var/db/vespa/search/cluster.sigbushandler/n0"
  end

  def self.testparameters
    { "ELASTIC" => { :search_type => "ELASTIC"} }
  end

  def get_app(stoponioerrors)
    app = SearchApp.new.cluster_name("sigbushandler").
      sd(SEARCH_DATA+"music.sd")
    if (stoponioerrors)
      app.config(ConfigOverride.new("vespa.config.search.core.proton").
                 add("stoponioerrors", "true"))
    end
    return app
  end

  def wait_systemstate
    20.times do
      if vespa.logserver.log_matches(/SYSTEMSTATE.*All partitions are down/) > 0
        break
      end
      sleep 1
    end
  end

  def test_sigbushandler
    set_expected_logged(/proton state string is/)
    app = get_app(false)
    deploy_app(app)
    start_feed_and_check(false)
  end

  def test_sigbushandler_stop
    set_expected_logged(/proton state string is/)
    app = get_app(true)
    deploy_app(app)
    start_feed_and_check(true)
  end

  def start_feed_and_check(stoponioerrors)
    start
    feed_and_check(stoponioerrors)
  end

  def triggerflush(node)
    fcnt = vespa.logserver.log_matches(/.*flush\.complete.*memoryindex/)
    20.times do
      node.trigger_flush
      if vespa.logserver.log_matches(/.*flush\.complete.*memoryindex/) > fcnt
        break
      end
      puts "Sleep 2 seconds before next trigger_flush"
      sleep 2
    end
    assert_log_matches(/.*diskindex\.load\.complete/)
    assert_log_matches(/.*flush\.complete.*memoryindex/)
  end

  def normalize_ts(line)
    return line.sub(/ ts=[0-9.]*/, ' ts=0.0')
  end

  def normalize_addr(line)
    return line.sub(/ addr=0x[0-9a-f]*/, ' addr=0x0')
  end

  def read_state(node)
    line = node.get_stateline("#{@datadir}/state")
    line = normalize_ts(line)
    line = normalize_addr(line)
    return line
  end

  def feed_and_check(stoponioerrors)
    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=country", 1)
    assert_hitcount("query=title:country", 1)
    assert_hitcount("query=mid:2", 10)
    assert_hitcount("query=sddocname:music", 10)
    assert_result("query=sddocname:music&nocache",
                   SEARCH_DATA+"music.10.result.xml",
                   "title", ["title", "surl", "mid"])
    vespa.search["sigbushandler"].first.
      execute("vespa-proton-cmd --local getState")
    vespa.search["sigbushandler"].first.
      execute("/sbin/sysctl kernel.core_pattern")
    assert_hitcount("query=title:country&nocache", 1)
    # make sure the memory index is flushed to disk
    node = vespa.search["sigbushandler"].first
    triggerflush(node)
    assert_hitcount("query=title:country&nocache", 1)

    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    corefile = "vespa-proton-bi.core." + pid + ".lz4"
    cores_before = node.find_coredumps(@starttime, corefile)
    assert(cores_before.empty?, "Expected no core file.")

    node.execute("truncate --size=0 #{@datadir}" +
                 "/documents/music" +
                 "/0.ready/index/index.flush.1" +
                 "/title/posocc.dat.compressed")
    # Proton is supposed to crash here, thus expected hitcount is 0
    assert_hitcount("query=title:country&nocache", 0)
    if stoponioerrors
      wait_systemstate
    end
    sleep @coredump_sleep
    node.stop

    cores_after = node.find_coredumps(@starttime, corefile)
    assert_equal(1, cores_after.size, "Expected 1 core file.")

    state = read_state(node)
    assert_equal("state=down ts=0.0 operation=sigbus errno=0 code=2 addr=0x0",
                 state, "Unexpected state file content")
    if stoponioerrors
      assert_log_matches(/SYSTEMSTATE.*All partitions are down/);
    end

    node.execute("rm #{cores_after.first} #{cores_after.first}.core")
  end

  def teardown
    stop
    @valgrind = false
    @valgrind_opt = nil
  end

end
