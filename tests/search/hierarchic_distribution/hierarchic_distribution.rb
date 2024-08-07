# Copyright Vespa.ai. All rights reserved.
require_relative 'feed_and_query_test_base'

class HierarchicDistributionTest < FeedAndQueryTestBase

  def setup
    set_owner("geirst")
    super
  end

  def timeout_seconds
    60 * 80
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
    sleep 1 # We need at least one ping round to establish group coverage
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
    run_basic_search_test(3, 3, true)
    verify_ready_copies_per_group(1)
    stop_and_not_wait(0) # group 0 still has enough nodes
    assert_atleast_some_queries([nil,50,50, 50,50,50, 50,50,nil], 300)
    stop_and_not_wait(3) # group 1 still has enough nodes
    assert_atleast_some_queries([nil,50,50, nil,50,50, 50,50,nil], 300)
    stop_and_not_wait(2) # group 0 is down
    assert_atleast_some_queries([nil,0,nil, nil,10,10, 10,10,nil], 300)
    stop_and_not_wait(4) # group 1 is down
    assert_atleast_some_queries([nil,0,nil, nil,nil,0, 10,10,nil], 100)
    stop_and_not_wait(6) # row 2 is also down, will make do with whatever we have.
    assert_atleast_some_queries([nil,50,nil, nil,nil,50, nil,50,nil], 300)
  end

  def test_less_ready_than_redundancy
    set_description("Test that search works correctly with less ready than redundancy copies")
    run_basic_search_test(3)
    verify_ready_copies_per_group(1)
  end

end
