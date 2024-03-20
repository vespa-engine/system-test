# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class StoreUnknownRemoves < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    set_description("Try to resurrect a removed document")
  end

  def teardown
    stop
  end

  def test_store_unknown_removes
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new.
                       sd(selfdir + "test.sd").
                       num_parts(4).
                       redundancy(2).
                       ready_copies(1)))
    start

    feed(:file => selfdir+"feed.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:test", 1)

    @stopped = []

    for i in 0..3
      if node_has_doc(i, "total")
        stop_node(i)
        break
      end
    end

    feed(:file => selfdir+"remove.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:test", 0)

    has_removed_doc = []
    for i in 0..3
      if @stopped.include?(i)
        next
      end
      if node_has_doc(i, "removed")
        has_removed_doc << i
      end
    end

    has_removed_doc.each do |i|
      stop_node(i)
    end
    assert_equal(3, @stopped.length)

    my_node = @stopped[0]
    start_node(my_node)
    assert(!node_has_doc(my_node, "total"))
    assert(node_has_doc(my_node, "removed"))
  end

  def node_has_doc(index, stat)
    puts "checking node #{index}"
    search_node = vespa.search["search"].searchnode[index]
    doc_stats = search_node.get_state_v1_custom_component("/documentdb/test")["documents"]
    puts "document stats:" + doc_stats.to_s
    return doc_stats[stat] == 1
  end

  def stop_node(index)
    puts("Stopping node #{index}.")
    stop_node_and_wait("search", index)
    puts("Node #{index} stopped.")
    @stopped << index
  end

  def start_node(index)
    puts("Starting node #{index}.")
    start_node_and_wait("search", index)
    puts("Node #{index} started.")
    @stopped.delete(index)
  end
end
