# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class SlowQuery < IndexedSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))#.qrserver(QrserverCluster.new))
    start
  end

  def test_slow_query

    node = vespa.adminserver
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c && ./a.out | vespa-feed-perf")
    puts "compile and feed output: #{output}"

    wait_for_hitcount("sddocname:simple", 400)
    assert_hitcount("foobar", 400)

    puts "Doing 10 queries using misbehaving client."
    could_query = false
    vespa.adminserver.copy(selfdir + "BadClient.java", dirs.tmpdir)
    vespa.adminserver.execute("javac -d #{dirs.tmpdir} #{dirs.tmpdir}/BadClient.java")
    qrserver = vespa.container.values.first
    3.times do
      hname = qrserver.name
      sport = qrserver.http_port
      vespa.adminserver.execute("java -cp #{dirs.tmpdir} com.yahoo.prelude.test.BadClient #{hname} #{sport}")
      if $?.exitstatus == 0
        could_query = true
      end
    end
    assert(could_query, "Could not query QRS successfully in 10 tries.")
    # Now to try and make sure the messages propagates to the log file
    sleep 10
    qrserver.stop
    sleep 10
    numlogs = assert_log_matches(/container.*Slow execution/)
    puts "GOT log matches: #{numlogs} messages about Slow execution"

    i = 0
    query_time_sum = 0.0
    10.times do
        i += 1
        entry = qrserver.execute("cat #{Environment.instance.vespa_home}/logs/vespa/qrs/JsonAccessLog.default.* | grep foobar | head -#{i+1} | tail -1").chomp
        assert(entry && entry != "", "Could not find foobar in JsonAccessLog.default")
        puts "GOT entry #{entry}"
        j = JSON.parse entry
        query_time = j['duration']
        assert(query_time, "Could not find query time in log entry: #{j}")
        puts "GOT Query time from access log: #{query_time}"
        query_time_sum += query_time.to_f
    end
    query_time_avg = query_time_sum / i
    puts "GOT Query time from access log: #{query_time_avg}"
    assert(query_time_avg.to_f <= 11.0, "Too long query time")
  end

  def teardown
    stop
  end

end
