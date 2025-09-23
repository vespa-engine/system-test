# Copyright Vespa.ai. All rights reserved.

require 'search_test'
require 'app_generator/search_app'

class CpuPinning < SearchTest

  def setup
    set_owner('baldersheim')

    deploy_app(SearchApp.new.
                 container(Container.new.cpu_socket_affinity(true).
                             documentapi(ContainerDocumentApi.new).
                             search(Searching.new)).
               cluster(SearchCluster.new.
                  sd(SEARCH_DATA + 'music.sd').
                  group(NodeGroup.new(0, nil).
                       default_nodes(1, 0).
                       cpu_socket_affinity(true))))
    start
  end

  def test_cpu_pinning
    feed(:file => SEARCH_DATA+"music.10.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
  end


end
