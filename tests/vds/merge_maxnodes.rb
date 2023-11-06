# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class MergingMaxNodesTest < VdsTest

  def setup
    set_owner("vekterli")
    @timeout = 600
    @valgrind = false
    deploy_app(default_app.
            num_nodes(6).
            redundancy(6).
            max_nodes_per_merge(4).
            min_storage_up_ratio(0.1))
    start
  end

  def content_cluster
    vespa.storage['storage']
  end

  def take_down_all_content_nodes
    for i in 0..5
      puts "->  Stopping storage node #{i}..."
      vespa.stop_content_node("storage", i, 0)
    end
    # Cannot wait on 6 downed nodes here, since CC won't bother sending out
    # new cluster state versions if the cluster itself is down.
    content_cluster.wait_until_cluster_down
  end
  def take_down_all_distributor_nodes
    for i in 0..5
      puts "->  Stopping distributor node #{i}..."
      content_cluster.distributor["#{i}"].stop(300, false)
    end
  end
  def take_up_all_content_nodes
    for i in 0..5
      puts "->  Starting storage node #{i}..."
      vespa.start_content_node("storage", i, 0)
    end
  end
  def take_up_all_distributor_nodes
    for i in 0..5
      puts "->  Starting distributor node #{i}..."
      content_cluster.distributor["#{i}"].start()
    end
  end

  def feed_doc_in_turn_to_all_nodes
    for i in 0..5
      puts "->  Taking node #{i} up to feed it a unique doc"
      vespa.start_content_node("storage", i)
      puts "->  Feeding unique doc to node #{i}"
      doc = Document.new("music", "id:test:music:n=1:doc#{i}")
      vespa.document_api_v1.put(doc)
      puts "->  Taking node #{i} back down"
      vespa.stop_content_node("storage", i)
    end
  end

  def parseStat(data)
    nodedata = data.split(/node/)
    nodedata.shift
    copydata = Array.new
    nodedata.each { |a|
        if (a =~ /idx=(\d+),.*docs=(\d+)\//)
            info = "#{$1}-#{$2}"
            copydata.push(info)
        else
            raise "Failed to match '#{a}'"
        end
    }
    return copydata.join(",")
  end

  def test_merge_max_nodes
    # Feed one unique doc to each node (Have to take them up one at a time)
    take_down_all_content_nodes
    feed_doc_in_turn_to_all_nodes()
    take_down_all_distributor_nodes
    take_up_all_content_nodes
    take_up_all_distributor_nodes

    content_cluster.wait_for_node_count("storage", 6, "u")
    content_cluster.wait_for_node_count("distributor", 6, "u")

    # Wait for cluster to get back up and synchronize
    puts "->  Wait for cluster to be up and merge all 6 nodes"
    content_cluster.wait_until_ready

    # Verify that all copies indeed are equal with 6 docs
    res = content_cluster.distributor["0"].execute("vespa-stat --user 1")
    copies = parseStat(res)
    assert_equal("3-6,5-6,0-6,2-6,1-6,4-6", copies)

    # Since we cannot establish any global barriers on when distributors may decide
    # they want to schedule merges when the nodes are being started, we cannot reliably
    # assert on the _number_ of merge operations, just that the merge node limiter has
    # in fact kicked in.
    total_merges = content_cluster.distributor.each_value.map{|distr|
      distr.get_metric("vds.idealstate.nodes_per_merge")["count"] 
    }.reduce(:+)
    max_nodes_per_merge = content_cluster.distributor.each_value.map{|distr|
      distr.get_metric("vds.idealstate.nodes_per_merge")["max"] || 0 # nil when metric not set
    }.max
    puts "Total merges across all distributors: #{total_merges}, max nodes: #{max_nodes_per_merge}"
    assert total_merges >= 3
    assert_equal(4, max_nodes_per_merge)
  end

  def teardown
    stop
  end
end

