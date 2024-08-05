# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class CheckAutoRestart < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Tests that all the applications we run from config sentinel are auto-restarted when killed brutally")
    @ps = Hash.new
  end

  def killapp(app)
    @ps[app] = Hash.new
    vespa.nodeproxies.each_value do |node|
      @ps[app][node.name] = Hash.new
      pids = node.kill_process(app)
      raise "Unable to kill #{app}" if pids.empty?
      pids.each do |pid|
        @ps[app][node.name][pid] = true
      end
    end
  end

  def check_new_pids(app)
    limit = 60
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
    assert(!check_again, "Could not find pid for #{app}")
  end

  def test_check_auto_restart
    output = deploy_app(SearchApp.new.sd(selfdir+"banana.sd"))
    start

    puts "Killing various vespa processes"
    killapp("sbin/vespa-logd")
    killapp("sbin/vespa-distributord-bin")
    killapp("config.id=default/container.0")
    killapp("config.id=admin/standalone/cluster-controllers/0")
    killapp("sbin/vespa-proton")
    killapp("config.id=admin/metrics/")
    killapp("sbin/vespa-slobrok")

    check_new_pids("sbin/vespa-logd")
    check_new_pids("sbin/vespa-distributord-bin")
    check_new_pids("config.id=default/container.0")
    check_new_pids("config.id=admin/standalone/cluster-controllers/0")
    check_new_pids("sbin/vespa-proton")
    check_new_pids("config.id=admin/metrics/")
    check_new_pids("sbin/vespa-slobrok")

    wait_until_all_services_up(180)
    # Wait for container to come up again
    wait_for_application(vespa.container.values.first, output)

    puts "Feeding..."
    feed_and_wait_for_docs("banana", 2, :file => selfdir+"feed1.json")
    wait_for_hitcount("query=sddocname:banana", 2);
  end

  def teardown
    stop
  end

end
