# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class TestRecoveryMultiCluster < IndexedSearchTest

  def setup
    set_owner("vekterli")
  end

  def test_recovery_vds
    app = SearchApp.new.
          cluster(SearchCluster.new("music").
                  sd(selfdir + "music.sd").
                  num_parts(1)).
          cluster(SearchCluster.new("books").
                  sd(selfdir + "books.sd").
                  num_parts(1)).
          storage(StorageCluster.new("storage", 1).
                  sd(selfdir + "books.sd").
                  sd(selfdir + "music.sd").
                  group(NodeGroup.new(0, "foo").default_nodes(1, 0)))
    deploy_app(app)
    start
    puts "Test starting"
    feed_and_wait_for_docs("music", 10, :file => selfdir + "music.10.json",
	:route => "\"[AND:storage music]\"")
    feed_and_wait_for_docs("books", 15, :file => selfdir + "books.15.json",
	:route => "\"[AND:storage books]\"")

    puts "Stopping"
    vespa.stop_base

    puts "Cleaning"
    vespa.storage["storage"].storage["0"].execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.music/r0")
    puts "Starting"

    vespa.start_base

    vespa.storage["storage"].wait_until_ready

    sleep 10

    # Recover
    vespa.storage["storage"].storage["0"].execute("vespa-visit --cluster storage --datahandler music --selection music")
    vespa.storage["storage"].storage["0"].execute("vespa-visit --cluster storage --datahandler books --selection books")

    wait_for_hitcount("query=sddocname:music", 10)
    wait_for_hitcount("query=sddocname:books", 15)

    # Check that search works
    assert_result("query=sddocname:music",
                  selfdir+"music.10.result.json",
                  "title")

   assert_result("query=sddocname:books&hits=100",
                 selfdir+"books.15.result.json",
                 "title")
  end

  def teardown
    stop
  end

end
