# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_multi_model_test'
require 'environment'

class MergeChainingTest < VdsMultiModelTest

  def setup
    set_owner("vekterli")
    @valgrind = false
    @num_users = 100
    @docs_per_user = 100
    @feed_file = "tmpfeed_mergechaining.json"
    make_feed_file(@feed_file, "music", 0, @num_users - 1, @docs_per_user)

    deploy_app(default_app.num_nodes(4).redundancy(4))
    start
  end

  def teardown
    begin
      if File.exist?(@feed_file)
        File.delete(@feed_file)
      end
    ensure
      stop
    end
  end

  def node_name(name, index)
    if index == 0
      name
    else
      name + (index + 1).to_s
    end
  end

  def content_node(i)
    vespa.storage['storage'].storage[i.to_s]
  end

  def test_merge_chaining
    puts "Verifying initial document count"
    vespa.storage["storage"].assert_document_count(0)

    feedfile(@feed_file)

    vespa.storage["storage"].wait_until_ready

    puts "Verifying fed document count and that feeding has not caused any merges"
    vespa.storage["storage"].assert_document_count(@num_users * @docs_per_user)

    # Make sure simply feeding shouldn't trigger any merges
    for i in 0..2 do
      node = content_node(i)
      post_feed_merges  = node.get_metric("vds.mergethrottler.mergechains.ok")["count"]
      post_feed_merges += node.get_metric("vds.mergethrottler.locallyexecutedmerges.ok")["count"]
      assert_equal(0, post_feed_merges)
    end

    puts "Taking down node"
    vespa.stop_content_node("storage", 3)

    # Taking down the node will trigger merges of its own, so we wait until those are done
    puts "Waiting for downed node merges to trigger and complete"
    sleep 15
    vespa.storage["storage"].wait_until_ready

    puts "Verifying redundancy holds"
    vespa.storage["storage"].assert_document_count(@num_users * @docs_per_user)

    puts "Deleting contents of node 3"
    vespa.content_node("storage", 3).execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.storage/n3")

    merge_count = [0, 0, 0, 0]
    merge_baseline = [0, 0, 0, 0]

    for i in 0..2 do
      node = content_node(i)
      assert_no_active_or_queued_merges(node)

      merge_count[i]  = node.get_metric("vds.mergethrottler.mergechains.ok")["count"]
      merge_count[i] += node.get_metric("vds.mergethrottler.locallyexecutedmerges.ok")["count"]
      merge_baseline[i] = merge_count[i]
    end

    puts "merge baselines after node down: #{merge_baseline.inspect}"
    # Shouldn't cause any merges since we don't have anywhere to merge buckets to!
    for i in 0..2 do
      assert_equal(0, merge_baseline[i])
    end

    for i in 0..3 do
      content_node(i).logctl("#{node_name('searchnode', i)}:mergethrottler", 'debug=on')
    end
    sleep 5 # let log levels propagate

    puts "Bringing node back online"
    vespa.start_content_node("storage", 3)

    # If something goes wrong during merging (as in, a bug), this should time out due to
    # a distributor waiting for a merge reply it never will receive
    vespa.storage["storage"].wait_until_ready

    merge_count = [0, 0, 0, 0]

    for i in 0..3 do
      node = content_node(i)
      assert_no_active_or_queued_merges(node)

      merge_count[i]  = node.get_metric("vds.mergethrottler.mergechains.ok")["count"]
      merge_count[i] += node.get_metric("vds.mergethrottler.locallyexecutedmerges.ok")["count"]
      puts "Merge chains for node #{i}: #{merge_count[i]}"
    end

    assert merge_count[3] > 0

    # Number of seen merges should be the same on all nodes since we've
    # got 4 nodes and a redundancy of 4, meaning all nodes must be involved
    # in every merge
    for i in 0..2 do
      assert_equal(merge_count[3], merge_count[i] - merge_baseline[i])
    end

    puts "Checking doc count one last time"
    vespa.storage["storage"].assert_document_count(@num_users * @docs_per_user)
  end

  def assert_no_active_or_queued_merges(node)
      merge_status = node.get_status_page("/merges")
      puts merge_status
      assert_match(/Active merges \(0\)/, merge_status)
      assert_match(/Queued merges \(in priority order\) \(0\)/, merge_status)
  end

end
