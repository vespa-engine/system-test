# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'
require 'environment'

class RemoveIndexes < IndexedStreamingSearchTest

  def setup
    set_owner("hmusum")
  end

  def test_remove_indexes
    set_description("Test vespa-remove-index")
    deploy_app(SearchApp.new.sd("#{selfdir}/banana.sd"))
    start

    # Feed some documents
    feed_and_wait_for_docs("banana", 2, :file => selfdir + "bananafeed.json")

    @node = vespa.adminserver

    # Stop Vespa
    vespa.stop_base

    # Remove indexes
    @node.execute("vespa-remove-index -force")

    # Verify folders are empty
    res = @node.execute("ls #{Environment.instance.vespa_home}/var/db/vespa/index/ -a -I \".\" -I \"..\"")
    assert(res == "", "#{Environment.instance.vespa_home}/var/db/vespa/index/ is not empty")

    # Verify folders are empty
    res = @node.execute("ls #{Environment.instance.vespa_home}/var/db/vespa/search/ -a -I \".\" -I \"..\"")
    assert(res == "", "#{Environment.instance.vespa_home}/var/db/vespa/search/ is not empty")

    # Start vespa
    vespa.start_base
    wait_until_ready

    # Assert index is clean
    assert_hitcount("query=sddocname:banana", 0)

    # Feed some documents
    feed_and_wait_for_docs("banana", 2, :file => selfdir + "bananafeed.json")
  end

  def teardown
    stop
  end

end
