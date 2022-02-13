# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class TestRecovery < IndexedSearchTest

  def setup
    set_owner("vekterli")
    @valgrind = false
  end

  def test_recovery_vds
    app = SearchApp.new.
          cluster(SearchCluster.new("music").
                  sd(selfdir + "old/music.sd").
                  num_parts(2)).
          storage(StorageCluster.new("storage", 1).
                  sd(selfdir + "old/music.sd").
                  group(NodeGroup.new(0, "storage").default_nodes(1, 0)).
                  distribution_bits("16"))
    deploy_app(app)
    start
    vespa.storage["storage"].wait_until_ready
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA + "music.10.xml")
    assert_result("query=sddocname:music",
                   SEARCH_DATA+"music.10.result.json",
                   "title")
    puts "Stopping"
    vespa.stop_base

    puts "Cleaning"
    vespa.storage["storage"].storage["0"].execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.music/r0/c1")
    puts "Starting"
    vespa.start_base

    vespa.storage["storage"].wait_until_ready

    # Cannot perform partial search, distribution is subject to change
    
    # Cannot select on ideal storage node index, recover everything
    vespa.storage["storage"].storage["0"].execute("vespa-visit --cluster storage --selection music --datahandler music")
    
    # give QRS etc a chance to discover new data
    wait_for_hitcount("query=sddocname:music", 10)

    puts "Got data from visiting, now check if we are fully recovered"

    assert_result("query=sddocname:music",
                   SEARCH_DATA+"music.10.result.json",
                   "title")
  end

  def teardown
    stop
  end

end
