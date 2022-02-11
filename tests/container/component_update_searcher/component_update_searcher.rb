# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ComponentUpdateSearcher < SearchContainerTest

  def timeout_seconds
    return 1800
  end

  def setup
    set_owner("gjoranv")
    set_description("Verifies that a modified bundled searcher is updated in the qrs, when all config is unchanged.")
  end

  def enable_all_log_levels
    # @qrs.logctl(@qrs.servicetype, "all=on")
    @qrs.logctl("#{@qrs.servicetype}:com.yahoo.container.di", "debug=on")
    @qrs.logctl("configproxy:com.yahoo.vespa.config.proxy.ClientUpdater", "debug=on")
    @qrs.logctl("configproxy:com.yahoo.config.subscription.impl.JRTConfigRequester", "debug=on")
  end

  def redeploy(resultFile, bundle)
    output = deploy(selfdir + "app", nil, :bundles => [bundle])
    begin
      wait_for_application(@qrs, output)
    rescue
      res = search("query=test&tracelevel=3")
      flunk "Did not get expected application checksum.\n Current result from query=test:\n #{res.xmldata}"
    end
    assert_result("query=test", resultFile)
  end

  def test_updated_searcherbundle
    initial = add_bundle_dir(selfdir+"initial", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'initial')
    updated = add_bundle_dir(selfdir+"updated", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'updated')

    compile_bundles(@vespa.nodeproxies.values.first)
    deploy(selfdir + "app", nil, :bundles => [initial])

    start
    @qrs = (vespa.qrserver.values.first or vespa.container.values.first)
    wait_for_hitcount("query=test",0)  # Just wait for the Qrs to be up
    # enable_all_log_levels
    #system("vespa-get-config -n container.core.chains -i container/component/com.yahoo.search.handler.SearchHandler")

    res = search("query=test&tracelevel=3")
    puts "Result from query=test:"
    puts res.xmldata
    assert_result("query=test", selfdir + "initial_result.json")

    # Re-deploy with same app, but modified searcher bundle
    puts ">>>>>>>>>>>> Deploying the updated searcher"
    redeploy(selfdir + "updated_result.json", updated)

  end

  def teardown
    stop
  end

end
