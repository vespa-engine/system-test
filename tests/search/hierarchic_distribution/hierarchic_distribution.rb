# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_and_query_test_base'

class HierarchicDistributionTest < FeedAndQueryTestBase

  def setup
    @valgrind = false
    @query_counts_bias = nil
    set_owner("geirst")
    super
  end

  def timeout_seconds
    60 * 80
  end

  def create_app(num_fdispatch_threads = 3, ready_copies = 6, redundancy = 6, odd_sized_groups = false, min_group_coverage=100.0) # 1 administrative, 1 search, 1 docsum thread
    SearchApp.new.cluster(
      SearchCluster.new("mycluster").sd(selfdir + "test.sd").
      redundancy(redundancy).ready_copies(ready_copies).
      dispatch_policy(odd_sized_groups ? "random" : "round-robin").
      min_group_coverage(min_group_coverage).
      group(create_groups(redundancy, odd_sized_groups))).
        storage(StorageCluster.new("mycluster", 9)).
        monitoring("test", "60")
  end

  def create_groups(redundancy, odd_sized_groups)
    NodeGroup.new(0, "mytopgroup").
      distribution(redundancy == 6 ? "2|2|*" : "1|1|*").
      group(NodeGroup.new(0, "mygroup0").
            node(NodeSpec.new("node1", 0)).
            node(NodeSpec.new("node1", 1)).
            node(NodeSpec.new("node1", 2))).
      group(NodeGroup.new(1, "mygroup1").
            node(NodeSpec.new("node1", 3)).
            node(NodeSpec.new("node1", 4)).
            node(NodeSpec.new("node1", 5))).
      group(odd_sized_groups ?
              NodeGroup.new(2, "mygroup2").
                node(NodeSpec.new("node1", 6)).
                node(NodeSpec.new("node1", 7)) :
              NodeGroup.new(2, "mygroup2").
                node(NodeSpec.new("node1", 6)).
                node(NodeSpec.new("node1", 7)).
                node(NodeSpec.new("node1", 8)))
  end

  def get_num_queries_all(exp_per_node)
    search_nodes = @vespa.search["mycluster"].searchnode
    num_queries = []
    exp_per_node.each_index do |i|
      if exp_per_node[i]
        node = search_nodes[i]
        metrics = node.get_total_metrics
        bias_count = (@query_counts_bias != nil) ? @query_counts_bias[i] : 0
        num_queries.push(get_num_queries(metrics) - bias_count)
      else
        num_queries.push(nil)
      end
    end
    return num_queries
  end

  def sub_arrays(a, b)
    a.zip(b).map { |x,y| x != nil ? (x - y) : nil }
  end

  def assert_atleast_num_queries(exp_queries, act_queries)
    exp_queries.each_index do |i|
      if exp_queries[i]
        assert(act_queries[i] >= exp_queries[i], "Expected atleast #{exp_queries[i]} received queries for search node #{i}, but was only #{act_queries[i]}")
      end
    end
  end

  def assert_num_queries(exp_per_node, atleast = false)
    act_query_counts = get_num_queries_all(exp_per_node)
    puts "assert_num_queries(): exp_per_node=#{array_to_s(exp_per_node)}, actual_query_counts=#{array_to_s(act_query_counts)}"
    exp_per_node.each_index do |i|
      exp_queries = exp_per_node[i]
      if exp_queries
        act_queries = act_query_counts[i]
        if atleast
          puts "search_node[#{i}]: group/row(#{i/3}), atleast_exp_queries(#{exp_queries}), act_queries(#{act_queries})"
          assert(exp_queries <= act_queries, "Expected atleast #{exp_queries} received queries for search node #{i}, but was only #{act_queries}")
        else
          puts "search_node[#{i}]: group/row(#{i/3}), exp_queries(#{exp_queries}), act_queries(#{act_queries})"
          assert_equal(exp_queries, act_queries, "Expected #{exp_queries} received queries for search node #{i}, but was #{act_queries}")
        end
      else
        puts "search_node[#{i}]: group/row(#{i/3}), down"
      end
    end
  end

  def get_num_queries(metrics)
    metrics.get("content.proton.documentdb.matching.queries", {"documenttype" => "test"})["count"].to_i
  end

  def stop_and_wait(i)
    stop_node_and_wait("mycluster", i)
  end

  def stop_and_not_wait(i)
    stop_node_and_not_wait("mycluster", i)
  end

  def start_and_wait(i)
    start_node_and_wait("mycluster", i)
  end

  def configure_bucket_crosschecking(redundancy)
    vespa.storage['mycluster'].set_bucket_crosscheck_params(
        :check_active => :single_active_per_leaf_group,
        :check_redundancy => redundancy
    )
  end

  def forced_bucket_crosscheck
    vespa.storage['mycluster'].wait_until_ready
  end

  # Enable check when distributor is able to show what copies are ready or not
  def verify_ready_copies_per_group(wanted_amount)
    for i in 0...8
      #bucketdb = vespa.storage['mycluster'].distributor[i.to_s].getBucketDB()
      #bucketdb.each { |bucket|
      #  ready_count = Array.new(3)
      #  bucket.copies().each { |copy|
      #    if (copy.is_trusted())
      #      ++ready_count[ copy.index() / 3 ]
      #    end
      #  }
      #  assert_equal(wanted_amount, ready_count[0])
      #  assert_equal(wanted_amount, ready_count[1])
      #  assert_equal(wanted_amount, ready_count[2])
      #}
    end
  end

  def test_basic_search
    set_description("Test that queries are sent to one fixed group/row when using hierarchic distribution")
    run_basic_search_test(6)
    verify_ready_copies_per_group(2)
  end

  def test_basic_search_odd_sized_groups
    set_description("Test that hetrogeneous groups work fine.")
    run_basic_search_test(3, 3, true)
    verify_ready_copies_per_group(1)
  end

  def assert_atleast_some_queries(exp_queries, count)
    before = get_num_queries_all(exp_queries)
    puts "before: " + before.inspect
    for i in 0...count do
      assert_query_hitcount
    end
    after = get_num_queries_all(exp_queries)
    puts "after: " + after.inspect
    diff = sub_arrays(after, before)
    puts "diff: " + diff.inspect
    assert_atleast_num_queries(exp_queries, diff)
  end

  def test_allowed_coverage_loss
    set_description("Test that one group can continue serving with coverage loss distribution")
    run_basic_search_test(3, 3, true, 60.0)
    verify_ready_copies_per_group(1)
    stop_and_not_wait(0) #group/row 0 still has enough nodes
    assert_atleast_some_queries([nil,50,50, 50,50,50, 50,50,nil], 300)
    stop_and_not_wait(3) #group/row 1 still has enough nodes
    assert_atleast_some_queries([nil,50,50, nil,50,50, 50,50,nil], 300)
    stop_and_not_wait(2) #group/row 0 is down
    assert_atleast_some_queries([nil,0,nil, nil,100,100, 100,100,nil], 300)
    stop_and_not_wait(4) #group/row 1 is down
    assert_atleast_some_queries([nil,0,nil, nil,nil,0, 100,100,nil], 100)
    stop_and_not_wait(6) #group/row 2 is also down, will make do with whatever we have.
    assert_atleast_some_queries([nil,50,nil, nil,nil,50, nil,50,nil], 300)
  end

  def test_less_ready_than_redundancy
    set_description("Test that search works correctly with less ready than redundancy copies")
    run_basic_search_test(3)
    verify_ready_copies_per_group(1)
  end

  def test_no_ready_copies
    set_description("Test that search works correctly with no ready copies. Active copy should be indexed anyhow")
    run_basic_search_test(0)
    verify_ready_copies_per_group(1)
  end

  def run_basic_search_test(ready_copies, redundancy = 6, odd_sized_group=false, min_group_size=100.0)
    deploy_app(create_app(3, ready_copies, redundancy, odd_sized_group, min_group_size))
    configure_bucket_crosschecking(redundancy)
    start
    generate_and_feed_docs

    forced_bucket_crosscheck
    if odd_sized_group then
      assert_odd_sized_groups
    else
      assert_even_sized_groups
    end
  end

  def assert_even_sized_groups
    assert_query_hitcount #group/row 0
    assert_num_queries([1, 1, 1, 0, 0, 0, 0, 0, 0])
    assert_query_hitcount #group/row 1
    assert_num_queries([1, 1, 1, 1, 1, 1, 0, 0, 0])
    assert_query_hitcount #group/row 2
    assert_num_queries([1, 1, 1, 1, 1, 1, 1, 1, 1])
    assert_query_hitcount #group/row 0
    assert_num_queries([2, 2, 2, 1, 1, 1, 1, 1, 1])

    assert_query_hitcount(20, "0,1,2/0") #group/row 0
    assert_num_queries([3, 3, 3, 1, 1, 1, 1, 1, 1])
    assert_query_hitcount(20, "0,1,2/1") #group/row 1
    assert_num_queries([3, 3, 3, 2, 2, 2, 1, 1, 1])
    assert_query_hitcount(20, "0,1,2/2") #group/row 2
    assert_num_queries([3, 3, 3, 2, 2, 2, 2, 2, 2])
  end

  def assert_odd_sized_groups
    for i in 1...4500 do
      assert_query_hitcount
    end
    assert_num_queries([400, 400, 400, 400, 400, 400, 400, 400, nil], true)
  end

  def test_dispatch_when_nodes_down_and_up_with_less_ready_copies
    set_description("Test that dispatch can handle nodes going down in a fixed group/row when doing search, using less ready copies than redundancy")
    run_nodes_down_and_up_test(3)
  end

  def test_dispatch_when_nodes_down_and_up_with_no_ready_copies
    set_description("Test that dispatch can handle nodes going down in a fixed group/row when doing search, using no ready copies")
    run_nodes_down_and_up_test(0)
  end

  def test_dispatch_when_nodes_down_and_up
    set_description("Test that dispatch can handle nodes going down in a fixed group/row when doing search")
    run_nodes_down_and_up_test(6)
  end

  def array_to_s(array)
    "[#{array.join(',')}]"
  end

  def align_fdispatch_to_use_group_0_next
    assert_query_hitcount
    search_nodes_dummy_counts = [0,0,0,0,0,0,0,0,0]
    act_query_counts = get_num_queries_all(search_nodes_dummy_counts)
    puts "align_fdispatch_to_use_group_0_next: act_query_counts=#{array_to_s(act_query_counts)}"
    if act_query_counts == [1,1,1,0,0,0,0,0,0]
      assert_query_hitcount
      assert_query_hitcount
    elsif act_query_counts == [0,0,0,1,1,1,0,0,0]
      assert_query_hitcount
    elsif act_query_counts != [0,0,0,0,0,0,1,1,1]
      raise "Unexpected query counts from search nodes: #{array_to_s(act_query_counts)}. Something wrong with how queries are dispatched"
    end
    @query_counts_bias = get_num_queries_all(search_nodes_dummy_counts)
    puts "align_fdispatch_to_use_group_0_next: query_counts_bias=#{array_to_s(@query_counts_bias)}"
  end

  def clear_query_counts_bias(index_to_clear)
    @query_counts_bias[index_to_clear] = 0
    puts "clear_query_counts_bias(#{index_to_clear}): #{array_to_s(@query_counts_bias)}"
  end

  def run_nodes_down_and_up_test(ready_copies)
    deploy_app(create_app(3, ready_copies))
    configure_bucket_crosschecking(6)
    start
    generate_and_feed_docs
    align_fdispatch_to_use_group_0_next

    assert_query_hitcount #group/row 0
    assert_num_queries([1, 1, 1, 0, 0, 0, 0, 0, 0])
    assert_query_hitcount #group/row 1
    assert_num_queries([1, 1, 1, 1, 1, 1, 0, 0, 0])
    assert_query_hitcount #group/row 2
    assert_num_queries([1, 1, 1, 1, 1, 1, 1, 1, 1])

    stop_and_wait(0) #group/row 0 still has enough nodes
    assert_query_hitcount #group/row 0
    assert_num_queries([nil, 2, 2, 1, 1, 1, 1, 1, 1])
    assert_query_hitcount #group/row 1
    assert_num_queries([nil, 2, 2, 2, 2, 2, 1, 1, 1])
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, 2, 2, 2, 2, 2, 2, 2, 2])

    configure_bucket_crosschecking(5)
    stop_and_wait(1) #group/row 0 has too few nodes
    assert_query_hitcount #group/row 1
    assert_num_queries([nil, nil, 2, 3, 3, 3, 2, 2, 2])
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, 3, 3, 3, 3, 3, 3])
    assert_query_hitcount #group/row 1
    assert_num_queries([nil, nil, 2, 4, 4, 4, 3, 3, 3])

    stop_and_wait(3) #group/row 1 still has enough nodes
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, 4, 4, 4, 4, 4])
    assert_query_hitcount #group/row 1
    assert_num_queries([nil, nil, 2, nil, 5, 5, 4, 4, 4])
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, 5, 5, 5, 5, 5])

    configure_bucket_crosschecking(4)
    stop_and_wait(4) #group/row 1 has too few nodes
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, nil, 5, 6, 6, 6])
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, nil, 5, 7, 7, 7])
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, nil, 5, 8, 8, 8])

    stop_and_wait(6) #group/row 2 still has enough nodes
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, nil, 5, nil, 9, 9])
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, nil, 5, nil, 10, 10])
    assert_query_hitcount #group/row 2
    assert_num_queries([nil, nil, 2, nil, nil, 5, nil, 11, 11])

    configure_bucket_crosschecking(3)
    stop_and_wait(7) #group/row 2 has too few nodes
    # all groups/rows has too few nodes
    run_query #group/row 0
    assert_num_queries([nil, nil, 3, nil, nil, 5, nil, nil, 11])
    run_query #group/row 1
    assert_num_queries([nil, nil, 3, nil, nil, 6, nil, nil, 11])
    run_query #group/row 2
    assert_num_queries([nil, nil, 3, nil, nil, 6, nil, nil, 12])

    configure_bucket_crosschecking(4)
    clear_query_counts_bias(0)
    start_and_wait(0) #group/row 0 has enough nodes again
    assert_query_hitcount #group/row 0
    assert_num_queries([1, nil, 4, nil, nil, 6, nil, nil, 12])
    assert_query_hitcount #group/row 0
    assert_num_queries([2, nil, 5, nil, nil, 6, nil, nil, 12])
    assert_query_hitcount #group/row 0
    assert_num_queries([3, nil, 6, nil, nil, 6, nil, nil, 12])

    configure_bucket_crosschecking(5)
    clear_query_counts_bias(3)
    start_and_wait(3) #group/row 1 has enough nodes again
    assert_query_hitcount #group/row 1
    assert_num_queries([3, nil, 6, 1, nil, 7, nil, nil, 12])
    assert_query_hitcount #group/row 0
    assert_num_queries([4, nil, 7, 1, nil, 7, nil, nil, 12])
    assert_query_hitcount #group/row 1
    assert_num_queries([4, nil, 7, 2, nil, 8, nil, nil, 12])

    configure_bucket_crosschecking(6)
    clear_query_counts_bias(6)
    start_and_wait(6) #group/row 2 has enough nodes again
    assert_query_hitcount #group/row 2
    assert_num_queries([4, nil, 7, 2, nil, 8, 1, nil, 13])
    assert_query_hitcount #group/row 0
    assert_num_queries([5, nil, 8, 2, nil, 8, 1, nil, 13])
    assert_query_hitcount #group/row 1
    assert_num_queries([5, nil, 8, 3, nil, 9, 1, nil, 13])
    assert_response_code_from_vip_handler(200)

    # Add test for status.html
    stop_and_not_wait(0) #group/row 2 has too few nodes
    sleep 3
    assert_response_code_from_vip_handler(200)
    stop_and_not_wait(2) #group/row 2 has too few nodes
    sleep 3
    assert_response_code_from_vip_handler(200)
    stop_and_not_wait(3) #group/row 2 has too few nodes
    sleep 3
    assert_response_code_from_vip_handler(200)
    stop_and_not_wait(5) #group/row 2 has too few nodes
    sleep 3
    assert_response_code_from_vip_handler(200)
    stop_and_not_wait(6) #group/row 2 has too few nodes
    sleep 3
    assert_response_code_from_vip_handler(200)
    stop_and_not_wait(8) #group/row 2 has too few nodes
    sleep 3
    assert_response_code_from_vip_handler(404)
  end

  def assert_response_code_from_vip_handler(expected_response_code, path="/status.html")
    qrserver = vespa.container.values.first
    s_name = qrserver.name
    s_port = qrserver.http_port

    assert_nothing_raised() { TCPSocket.new(s_name, s_port) }

    assert_nothing_raised() {
      response = https_client.get(s_name, s_port, path)
      assert_equal(expected_response_code.to_s, response.code);
    }
  end

end
