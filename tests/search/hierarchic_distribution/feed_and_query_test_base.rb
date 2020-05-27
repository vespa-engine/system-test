# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'search/utils/elastic_doc_generator'

class FeedAndQueryTestBase < SearchTest

  def setup
    @base_query = "query=sddocname:test&nocache&hits=0"
    Dir::mkdir("#{dirs.tmpdir}/generated")
  end

  def teardown
    stop
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
    hitcount = search_withtimeout(10, query).hitcount
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

end

