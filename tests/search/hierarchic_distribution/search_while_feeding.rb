# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_and_query_test_base'

class SearchWhileFeedingAndNodesDownAndUpTest < FeedAndQueryTestBase

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
        config(ConfigOverride.new("vespa.config.search.core.fdispatchrc").add("maxthreads", num_fdispatch_threads)).
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

  def stop_and_wait(i)
    stop_node_and_wait("mycluster", i)
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

  def generate_docs(file_name, start, count)
    ElasticDocGenerator.write_docs(start, count, "#{dirs.tmpdir}/generated/#{file_name}")
  end

  def generate_removes(file_name, start, count)
    ElasticDocGenerator.write_removes(start, count, "#{dirs.tmpdir}/generated/#{file_name}")
  end

  def generate_updates(file_name, start, count)
    ElasticDocGenerator.write_updates(start, count, "#{dirs.tmpdir}/generated/#{file_name}")
  end

  def generate_feed_files(chunks)
    generate_docs("doc.0.xml", 0, 5*chunks)
    generate_removes("rem.00.xml", 0, chunks)
    generate_removes("rem.01.xml", chunks, chunks)
    generate_removes("rem.02.xml", 2*chunks, chunks)
    generate_removes("rem.03.xml", 3*chunks, chunks)
    generate_docs("doc.00.xml", 0, chunks)
    generate_docs("doc.01.xml", chunks, chunks)
    generate_docs("doc.02.xml", 2*chunks, chunks)
    generate_docs("doc.03.xml", 3*chunks, chunks)
    generate_updates("upd.00.xml", 0, chunks)
    generate_updates("upd.01.xml", chunks, chunks)
    generate_updates("upd.02.xml", 2*chunks, chunks)
    generate_updates("upd.03.xml", 3*chunks, chunks)
  end

  def feed_and_assert_hitcount(exp_hitcount, feed_file)
    puts "feed_and_assert_hitcount(#{exp_hitcount}, #{feed_file})"
    feed(:file => dirs.tmpdir + "generated/#{feed_file}")
    assert_group_hitcount(exp_hitcount)
  end

  def assert_group_hitcount(exp_hitcount)
    3.times do
      assert_query_hitcount(exp_hitcount)
    end
  end

  def wait_for_group_hitcount(exp_hitcount, search_paths)
    for i in 0...3 do
      query = get_query("#{search_paths[i]}/#{i}")
      puts "wait_for_hitcount(#{query}, #{exp_hitcount})"
      wait_for_hitcount(query, exp_hitcount)
    end
    assert_group_hitcount(exp_hitcount)
  end

  def test_search_while_feeding_and_nodes_down_and_up
    set_description("Test that all fixed groups/rows returns expected number of hits when feeding and nodes going down and up")
    # See BucketReadiness::test_readiness_while_nodes_down_and_up for similar test without
    # hierarchic distribution.
    deploy_app(create_app(150)) 
    configure_bucket_crosschecking(6)
    start

    chunks = 10
    generate_feed_files(chunks)

    feed_and_assert_hitcount(5*chunks, "doc.0.xml")

    # feed removes
    feed_and_assert_hitcount(4*chunks, "rem.00.xml")
    stop_and_wait_for_0_and_3(4*chunks)

    feed_and_assert_hitcount(3*chunks, "rem.01.xml")
    stop_and_wait_for_6_and_1(3*chunks)

    feed_and_assert_hitcount(2*chunks, "rem.02.xml")
    stop_and_wait_for_4_and_7(2*chunks)

    feed_and_assert_hitcount(chunks, "rem.03.xml")
    start_and_wait_for_all(chunks) #_

    # feed documents
    feed_and_assert_hitcount(2*chunks, "doc.00.xml")
    stop_and_wait_for_0_and_3(2*chunks)

    feed_and_assert_hitcount(3*chunks, "doc.01.xml")
    stop_and_wait_for_6_and_1(3*chunks)

    feed_and_assert_hitcount(4*chunks, "doc.02.xml")
    stop_and_wait_for_4_and_7(4*chunks)

    feed_and_assert_hitcount(5*chunks, "doc.03.xml")
    start_and_wait_for_all(5*chunks)

    # feed updates
    @base_query = "query=f2:2012&nocache"
    assert_group_hitcount(0)
    feed_and_assert_hitcount(chunks, "upd.00.xml")
    stop_and_wait_for_0_and_3(chunks)

    feed_and_assert_hitcount(2*chunks, "upd.01.xml")
    stop_and_wait_for_6_and_1(2*chunks)

    feed_and_assert_hitcount(3*chunks, "upd.02.xml")
    stop_and_wait_for_4_and_7(3*chunks)

    feed_and_assert_hitcount(4*chunks, "upd.03.xml")
    start_and_wait_for_all(4*chunks)
  end

  def stop_and_wait_for_0_and_3(exp_hitcount)
    configure_bucket_crosschecking(6)
    stop_and_wait(0)
    wait_for_group_hitcount(exp_hitcount, ["1,2","0,1,2","0,1,2"])
    stop_and_wait(3)
    wait_for_group_hitcount(exp_hitcount, ["1,2","1,2","0,1,2"])
  end

  def stop_and_wait_for_6_and_1(exp_hitcount)
    stop_and_wait(6)
    wait_for_group_hitcount(exp_hitcount, ["1,2","1,2","1,2"])
    configure_bucket_crosschecking(5)
    stop_and_wait(1)
    wait_for_group_hitcount(exp_hitcount, ["2","1,2","1,2"])
  end

  def stop_and_wait_for_4_and_7(exp_hitcount)
    configure_bucket_crosschecking(4)
    stop_and_wait(4)
    wait_for_group_hitcount(exp_hitcount, ["2","2","1,2"])
    configure_bucket_crosschecking(3)
    stop_and_wait(7)
    wait_for_group_hitcount(exp_hitcount, ["2","2","2"])
  end

  def start_and_wait_for_all(exp_hitcount)
    configure_bucket_crosschecking(4)
    start_and_wait(0)
    wait_for_group_hitcount(exp_hitcount, ["0,2","2","2"])
    configure_bucket_crosschecking(5)
    start_and_wait(3)
    wait_for_group_hitcount(exp_hitcount, ["0,2","0,2","2"])
    configure_bucket_crosschecking(6)
    start_and_wait(6)
    wait_for_group_hitcount(exp_hitcount, ["0,2","0,2","0,2"])
    start_and_wait(1)
    wait_for_group_hitcount(exp_hitcount, ["0,1,2","0,2","0,2"])
    start_and_wait(4)
    wait_for_group_hitcount(exp_hitcount, ["0,1,2","0,1,2","0,2"])
    start_and_wait(7)
    wait_for_group_hitcount(exp_hitcount, ["0,1,2","0,1,2","0,1,2"])
  end

end
