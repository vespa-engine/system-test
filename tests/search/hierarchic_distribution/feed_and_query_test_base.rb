# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'search/utils/elastic_doc_generator'

class FeedAndQueryTestBase < SearchTest

  def setup
    @valgrind = false
    @query_counts_bias = nil
    @base_query = "query=sddocname:test&nocache&hits=0"
    Dir::mkdir("#{dirs.tmpdir}/generated")
  end

  def teardown
    stop
  end

  def create_app(num_fdispatch_threads = 3, ready_copies = 6, redundancy = 6, odd_sized_groups = false) # 1 administrative, 1 search, 1 docsum thread
    SearchApp.new.cluster(
      SearchCluster.new("mycluster").sd(selfdir + "test.sd").
      redundancy(redundancy).ready_copies(ready_copies).
      dispatch_policy(odd_sized_groups ? "adaptive" : "round-robin").
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

  def generate_and_feed_docs(n_docs = 20)
    ElasticDocGenerator.write_docs(0, n_docs, dirs.tmpdir + "generated/docs.xml")
    feed(:file => dirs.tmpdir + "generated/docs.xml")
  end

  def assert_query_hitcount(exp_hitcount = 20, search_path = nil)
    hitcount = run_query(exp_hitcount, search_path)
    assert_equal(exp_hitcount, hitcount, "Expected #{exp_hitcount} hits, but was #{hitcount}")
  end

  def run_query(exp_hitcount = 20, search_path = nil)
    query = get_query(search_path)
    hitcount = search_with_timeout(10, query).hitcount
    puts "run_query(#{query}, #{exp_hitcount}): #{hitcount} hits" if search_path
    return hitcount
  end

  def get_query(search_path = nil)
    query = @base_query
    if search_path != nil
      query = query + "&model.searchPath=#{search_path}"
    end
    return query
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

  def array_to_s(array)
    "[#{array.join(',')}]"
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

  def run_basic_search_test(ready_copies, redundancy = 6, odd_sized_group=false)
    deploy_app(create_app(3, ready_copies, redundancy, odd_sized_group))
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

  def align_dispatch_to_use_group_0_next
    dummy_counts = [0,0,0,0,0,0,0,0,0]
    @query_counts_bias = get_num_queries_all(dummy_counts) # Search handler does a warmup query which may or may not hit the backend, since 8.170

    assert_query_hitcount
    act_query_counts = get_num_queries_all(dummy_counts)
    puts "align_dispatch_to_use_group_0_next: act_query_counts=#{array_to_s(act_query_counts)}"
    if act_query_counts == [1,1,1,0,0,0,0,0,0]
      assert_query_hitcount
      assert_query_hitcount
    elsif act_query_counts == [0,0,0,1,1,1,0,0,0]
      assert_query_hitcount
    elsif act_query_counts != [0,0,0,0,0,0,1,1,1]
      raise "Unexpected query counts from search nodes: #{array_to_s(act_query_counts)}. Something wrong with how queries are dispatched"
    end
    @query_counts_bias = nil
    @query_counts_bias = get_num_queries_all(dummy_counts)
    puts "align_dispatch_to_use_group_0_next: query_counts_bias=#{array_to_s(@query_counts_bias)}"
  end

  def assert_even_sized_groups
    align_dispatch_to_use_group_0_next

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
    @query_counts_bias = get_num_queries_all([0, 0, 0, 0, 0, 0, 0, 0, nil])
    for i in 1...4500 do
      assert_query_hitcount
    end
    assert_num_queries([400, 400, 400, 400, 400, 400, 400, 400, nil], true)
  end

end

