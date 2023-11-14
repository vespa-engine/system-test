# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ComponentContainerClusters < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verifies that it is possible to set up multiple container clusters, each cluster running a different set of handlers.")
  end

  def test_component_container_clusters
    clear_bundles()
    add_bundle(selfdir + "Cluster1Handler.java");
    add_bundle(selfdir + "Cluster2Handler.java");
    output = deploy(selfdir+"app")
    start
    wait_for_application(vespa.container['cluster1/0'], output)
    wait_for_application(vespa.container['cluster2/0'], output)

    res = vespa.container['cluster1/0'].search("/Cluster1")
    assertResult(res, "Cluster1Handler says hello!");

    res = vespa.container['cluster1/0'].search("/Cluster2")
    if (! res.xmldata =~ /Could not find \/Cluster2/) &&
         (! res.xmldata =~ /\/Cluster2.*Not Found/i)
           flunk "Expected some variant of 'cluster2 not found', but got: #{res.xmldata}"
    end

    res = vespa.container['cluster2/0'].search("/Cluster1")
    if (! res.xmldata =~ /Could not find \/Cluster1/) &&
         (! res.xmldata =~ /\/Cluster1.*Not Found/i)
           flunk "Expected some variant of 'cluster1 not found', but got: #{res.xmldata}"
    end

    res = vespa.container['cluster2/0'].search("/Cluster2")
    assertResult(res, "Cluster2Handler says hi!");
  end

  def assertResult(result, expected)
    count = 0
    ok = false
    while (!ok && count < 60)
      begin
        count = count + 1
        if expected == result.xmldata
          ok = true
          break
        else
          puts "expected: " + expected
          puts "actual: " + result.xmldata
       end
        sleep 1
      end
    end
    assert(ok)
  end

  def teardown
    stop
  end

end
