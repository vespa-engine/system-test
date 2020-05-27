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

end
