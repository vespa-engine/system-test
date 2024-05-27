# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class AddContainer < IndexedOnlySearchTest

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    set_owner("musum")
    set_description("Test adding a container to a node that already has a searchnode")
    @valgrind = false
  end

  def can_share_configservers?(method_name=nil)
    true
  end

  # TODO: Will get port conflicts when adding a container to node 1, so the deployment will
  # fail. Redeploying the original application should give a working cluster again
  def test_addcontainer
    set_expected_logged(/Fatal error while configuring|PortListenException: failed to listen on port|Could not create rpc server listening on|Failed to start status HTTP server using port|Could not bind fnet transport socket to tcp|Rpc port config has changed/)
    app_one_qrserver = SearchApp.new.num_hosts(@num_hosts).sd(SEARCH_DATA + "music.sd").
      slobrok("node1").
      qrserver(QrserverCluster.new("foo").
               node({ :hostalias => "node2" }))
    deploy_app(app_one_qrserver)
    start

    feed(:file => SEARCH_DATA + "music.10.json", :host => vespa.container.values.first.hostname)
    wait_for_hitcount("query=sddocname:music", 10)

    deploy_app(SearchApp.new.num_hosts(2).sd(SEARCH_DATA + "music.sd").
               slobrok("node2").
               qrserver(QrserverCluster.new("foo").
                        node({ :hostalias => "node1" }).
                        node({ :hostalias => "node2" })))
    begin
      start
    rescue RuntimeError
      puts "Failed starting Vespa"
    end
    # Go back to the previous app
    deploy_app(app_one_qrserver)
    wait_for_hitcount("query=sddocname:music", 10)
    feed(:file => SEARCH_DATA + "music.777.json", :host => vespa.container.values.first.hostname)
    wait_for_hitcount("query=sddocname:music", 787)
  end

  def teardown
    stop
  end
end

