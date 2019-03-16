# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'

class CheckAutoRestart < SearchTest

  def setup
    set_owner("musum")
    set_description("Tests that all the applications we run from config sentinel are auto-restarted when killed brutally")
    @ps = Hash.new
  end

  def nigthly?
    true
  end

  def killapp(app)
    @ps[app] = Hash.new
    vespa.nodeproxies.each_value do |node|
      @ps[app][node.name] = Hash.new
      pids = node.kill_process(app)
      pids.each do |pid|
        @ps[app][node.name][pid] = true
      end
    end
  end

  def check_new_pids(app)
    limit = 30
    start = Time.now.to_i
    pids = Hash.new
    while (Time.now.to_i - start < limit)
      check_again = false
      vespa.nodeproxies.each_value do |node|
        pids[node] = node.get_pids(app)
        if (pids[node].length <= 0)
          puts "Sleeping for 1 second while waiting for new pid for #{app}"
          sleep 1
          check_again = true
          break
        end
      end
      if check_again
        next
      end
      vespa.nodeproxies.each_value do |node|
        assert(pids[node].length > 0, "No pids for #{app}")
        pids[node].each do |pid|
          assert(@ps[app][node.name][pid] == nil, "Process #{app} (pid #{pid}) has not received new pid.")
          puts "Found new pid #{pid} for #{app} on node #{node}"
        end
      end
      break
    end
  end

  def test_check_auto_restart
    output = deploy_app(SearchApp.new.sd(selfdir+"banana.sd"))
    start

    puts "Killing various vespa processes"
    killapp("sbin/vespa-logd")
    killapp("sbin/vespa-storaged-bin")
    killapp("sbin/vespa-distributord-bin")
    # pid file is part of the output from ps, use that for services running in container
    killapp("container.pid")
    killapp("container-clustercontroller.pid")
    killapp("sbin/vespa-dispatch")
    killapp("sbin/vespa-proton")
    killapp("com.yahoo.vespa.metricsproxy.RpcServer")
    killapp("bin/vespa-slobrok")

    check_new_pids("sbin/vespa-logd")
    check_new_pids("sbin/vespa-storaged-bin")
    check_new_pids("sbin/vespa-distributord-bin")
    check_new_pids("container.pid")
    check_new_pids("container-clustercontroller.pid")
    check_new_pids("sbin/vespa-dispatch")
    check_new_pids("sbin/vespa-proton")
    check_new_pids("com.yahoo.vespa.metricsproxy.RpcServer")
    check_new_pids("bin/vespa-slobrok")

    wait_until_all_services_up(180)
    # Wait for container to come up again
    wait_for_application(vespa.container.values.first, output)

    puts "Feeding..."
    feed_and_wait_for_docs("banana", 2, :file => selfdir+"feed1.xml")
    wait_for_hitcount("query=sddocname:banana", 2);
  end

  def teardown
    stop
  end

end
