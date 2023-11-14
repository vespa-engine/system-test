# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/search_app'

class CpuPinning < SearchTest

  def setup
    set_owner('nobody')

    deploy_app(SearchApp.new.
               container(Container.new.cpu_socket_affinity(true).search(Searching.new)).
               cluster(SearchCluster.new.
                  sd(SEARCH_DATA + 'music.sd').
                  group(NodeGroup.new(0, nil).
                       default_nodes(1, 0).
                       cpu_socket_affinity(true))))
    start
  end

  def test_cpu_pinning
    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
  end

  def teardown
    stop
  end

end
