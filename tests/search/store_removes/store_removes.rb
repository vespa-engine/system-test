# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class StoreUnknownRemoves < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    set_description("Try to resurrect a removed document")
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
      if number_of_docs(i, "total") == 1
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
      if number_of_docs(i, "removed") == 1
        has_removed_doc << i
      end
    end

    has_removed_doc.each do |i|
      stop_node(i)
    end
    assert_equal(3, @stopped.length)

    node_index = @stopped[0]
    start_node(node_index)
    assert_number_of_docs(node_index, "total", 0)
    assert_number_of_docs(node_index, "removed", 1)
  end

  def number_of_docs(index, stat)
    puts "checking node #{index}"
    search_node = vespa.search["search"].searchnode[index]
    doc_stats = search_node.get_state_v1_custom_component("/documentdb/test")["documents"]
    puts "document stats:" + doc_stats.to_s
    doc_stats[stat]
  end

  def assert_number_of_docs(index, stat, expected)
    count = number_of_docs(index, stat)
    assert_equal(expected, count, "unexpected doc count for '#{stat}' docs on node with index #{index}")
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
