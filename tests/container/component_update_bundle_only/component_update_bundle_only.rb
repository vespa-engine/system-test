# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'environment'

class ComponentUpdateBundleOnly < SearchContainerTest

  def timeout_seconds
    return 1800
  end

  def setup
    set_owner("gjoranv")
    set_description("Verifies that a modified bundle where both searcher and config is unchanged, does not throw an exception when redeploying. See bug #4366285.")
    @container = nil
  end

  def enable_all_log_levels
    @container.logctl(@container.servicetype, "all=on")
    @container.logctl("configproxy", "debug=on")
  end

  def redeploy(expected, bundle)
    output = deploy(selfdir + "app", nil, :bundles => [bundle])
    wait_for_application(@container, output)

    verify_handler_response(expected)
  end

  def test_updated_bundle_only
    initial = add_bundle_dir(selfdir+"initial", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'initial')
    updated = add_bundle_dir(selfdir+"updated", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'updated')
    compile_bundles(@vespa.nodeproxies.values.first)

    deploy(selfdir + "app", nil, :bundles => [initial])
    start
    @container = (vespa.qrserver.values.first or vespa.container.values.first)
    # enable_all_log_levels

    verify_handler_response("Initial handler")

    puts ">>>>>>>>>>>> Deploying the updated bundle"
    redeploy("Updated handler", updated)

  end

  def verify_handler_response(expected)
    result = @container.search("/Version")
    if expected == result.xmldata
      puts "Got expected response: #{expected}"
      return
    end

    puts "Test failed: Did not get expected result: #{expected}, got: #{result.xmldata}"
    puts "Waiting to see how long it takes to get expected result."
    ok = false
    count = 0
    while count < 10
      begin
        count = count + 1
        result = @container.search("/Version")
        if expected == result.xmldata
          puts "Got #{expected} after #{count} seconds"
          ok = true
          break
        else
          puts "& Try #{count}: result: #{result.xmldata}, expected: #{expected}"
        end
        sleep 1
      end
    end
    unless ok
      puts "xxxxxxxxxxxxx  Writing jstack output to file   xxxxxxxxxxxxxx"
      qrs_pid = @container.execute("pgrep -f -o prelude")
      f = File.new(selfdir+"/jstack.out", "w")
      f.puts(@container.execute("/usr/bin/sudo -u #{Environment.instance.vespa_user} jstack -l #{qrs_pid}"))
      f.close
    end
    flunk "Did not get expected response"
  end

  def teardown
    stop
  end


end
