# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'search/utils/elastic_doc_generator'

LidUsageStats = Struct.new(:lid_limit, :used_lids, :lowest_free_lid, :highest_used_lid, :lid_bloat_factor)

class LidSpaceCompactionTest < SearchTest

  def setup
    set_owner("geirst")
    @ignore_lid_limit = false
    @gen_random_removes = false
    `rm -rf #{dirs.tmpdir}/generated`
    Dir::mkdir("#{dirs.tmpdir}/generated")
  end

  def timeout_seconds
    2000
  end

  def setup_two_nodes(cluster)
      cluster.num_parts(2).redundancy(2).ready_copies(1)
  end

  def get_app(lid_bloat_factor = 0.2, two_nodes = false, disable_flush = false)
    cluster = SearchCluster.new.sd(SEARCH_DATA + "test.sd").
      allowed_lid_bloat(1).
      config(ConfigOverride.new("vespa.config.search.core.proton").
             add("lidspacecompaction", ConfigValues.new.
                 add("interval", 2.0).
                 add("allowedlidbloatfactor", lid_bloat_factor))).
      tune_searchnode({:resizing => {:'amortize-count' => 0}})
    cluster.disable_flush_tuning if disable_flush
    setup_two_nodes(cluster) if two_nodes
    app = SearchApp.new.cluster(cluster)
    app
  end

  def file_name_puts(begin_docs, num_docs)
    dirs.tmpdir + "generated/puts.#{begin_docs}.#{num_docs}.xml"
  end

  def file_name_updates(begin_docs, num_docs)
    dirs.tmpdir + "generated/updates.#{begin_docs}.#{num_docs}.xml"
  end

  def file_name_removes(begin_docs, end_docs, num_docs)
    dirs.tmpdir + "generated/removes.#{begin_docs}-#{end_docs}.#{num_docs}.xml"
  end

  def gen_puts(begin_docs, num_docs)
    puts "gen_puts(#{begin_docs}, #{num_docs})"
    file_name = file_name_puts(begin_docs, num_docs)
    @f1_term = "f1:word"
    @f2_term = "f2:2014"
    ElasticDocGenerator.write_docs(begin_docs, num_docs, file_name, { :field1 => 'word', :field2 => '2014' })
  end

  def gen_updates(begin_docs, num_docs)
    puts "gen_updates(#{begin_docs}, #{num_docs})"
    file_name = file_name_updates(begin_docs, num_docs)
    @f2_term = "f2:2019"
    ElasticDocGenerator.write_updates(begin_docs, num_docs, file_name, 2019)
  end

  def gen_removes(begin_docs, end_docs, num_docs)
    file_name = file_name_removes(begin_docs, end_docs, num_docs)
    if @gen_random_removes
      puts "gen_random_removes(#{begin_docs}, #{end_docs}, #{num_docs})"
      ElasticDocGenerator.write_random_removes(begin_docs, end_docs, num_docs, file_name)
    else
      puts "gen_removes(#{begin_docs}, #{num_docs})"
      ElasticDocGenerator.write_removes(begin_docs, num_docs, file_name)
    end
  end

  def feed_file(file_name, preserve_feed_order)
    if preserve_feed_order
      feed(:file => file_name, :maxpending => 1)
    else
      feed(:file => file_name)
    end
  end

  def feed_puts(begin_docs, num_docs, preserve_feed_order = false)
    file_name = file_name_puts(begin_docs, num_docs)
    if (!File.exists?(file_name))
      gen_puts(begin_docs, num_docs)
    end
    puts "feed_puts(#{begin_docs}, #{num_docs})"
    feed_file(file_name, preserve_feed_order)
  end

  def feed_updates(begin_docs, num_docs, preserve_feed_order = false)
    file_name = file_name_updates(begin_docs, num_docs)
    if (!File.exists?(file_name))
      gen_updates(begin_docs, num_docs)
    end
    puts "feed_updates(#{begin_docs}, #{num_docs})"
    feed_file(file_name, preserve_feed_order)
  end

  def feed_removes(begin_docs, end_docs, num_docs, preserve_feed_order = false)
    file_name = file_name_removes(begin_docs, end_docs, num_docs)
    if (!File.exists?(file_name))
      gen_removes(begin_docs, end_docs, num_docs)
    end
    puts "feed_removes(#{begin_docs}, #{end_docs}, #{num_docs})"
    feed_file(file_name, preserve_feed_order)
  end

  def assert_corpus_hitcount(num_docs)
    assert_hitcount("#{@f1_term}&hits=0", num_docs)
    assert_hitcount("#{@f2_term}&hits=0", num_docs)
  end

  def wait_for_corpus_hitcount(num_docs)
    wait_for_hitcount("#{@f1_term}&hits=0", num_docs)
    wait_for_hitcount("#{@f2_term}&hits=0", num_docs)
  end

  def print_corpus_hitcount(num_docs)
    puts "#{@f1_term} -> #{search("#{@f1_term}&hits=0").hitcount} / #{num_docs} hits"
    puts "#{@f2_term} -> #{search("#{@f2_term}&hits=0").hitcount} / #{num_docs} hits"
  end

  def get_lid_space_metric(metrics, sub_db, name)
    metrics.get("content.proton.documentdb.#{sub_db}.lid_space.#{name}", {"documenttype" => "test"})["last"]
  end

  def get_lid_usage_stats(metrics, sub_db)
    LidUsageStats.new(get_lid_space_metric(metrics, sub_db, "lid_limit").to_i,
                      get_lid_space_metric(metrics, sub_db, "used_lids").to_i,
                      get_lid_space_metric(metrics, sub_db, "lowest_free_lid").to_i,
                      get_lid_space_metric(metrics, sub_db, "highest_used_lid").to_i,
                      get_lid_space_metric(metrics, sub_db, "lid_bloat_factor").to_f)
  end

  def assert_lid_stats(lhs, rhs)
    if (lhs.lid_limit != nil)
      assert_equal(lhs.lid_limit, rhs.lid_limit)
    else
      assert(rhs.lid_limit > rhs.used_lids)
    end
    assert_equal(lhs.used_lids, rhs.used_lids)
    assert_equal(lhs.lowest_free_lid, rhs.lowest_free_lid)
    assert_equal(lhs.highest_used_lid, rhs.highest_used_lid)
  end

  def get_ideal_stats(used_lids, lid_limit = used_lids + 1)
    LidUsageStats.new(lid_limit, used_lids, used_lids + 1, used_lids, 0)
  end

  def get_ready_stats(metrics)
    get_lid_usage_stats(metrics, "ready")
  end

  def get_removed_stats(metrics)
    get_lid_usage_stats(metrics, "removed")
  end

  def get_not_ready_stats(metrics)
    get_lid_usage_stats(metrics, "notready")
  end

  def get_metrics
    vespa.search["search"].first.get_total_metrics
  end

  def get_all_lid_stats
    metrics = get_metrics
    act_ready = get_ready_stats(metrics)
    act_removed = get_removed_stats(metrics)
    act_not_ready = get_not_ready_stats(metrics)
    puts "ready.0:    " + act_ready.to_s
    puts "removed.1:  " + act_removed.to_s
    puts "notready.2: " + act_not_ready.to_s
    [act_ready, act_removed, act_not_ready]
  end

  def assert_ready_and_removed(exp_ready, exp_removed)
    stats = get_all_lid_stats
    assert_lid_stats(exp_ready, stats[0])
    assert_lid_stats(exp_removed, stats[1])
  end

  def stable_stats(exp_stats, act_stats)
    retval = (exp_stats.lowest_free_lid == act_stats.lowest_free_lid) &&
      (exp_stats.highest_used_lid == act_stats.highest_used_lid)
    if !@ignore_lid_limit
      return retval && (exp_stats.lid_limit == act_stats.lid_limit) &&
        (exp_stats.used_lids == act_stats.used_lids)
    end
    return retval
  end

  def wait_for_docs_moved(num_docs)
    puts "wait_for_docs_moved(#{num_docs})"
    ideal_ready = get_ideal_stats(num_docs)
    ideal_not_ready = get_ideal_stats(0)
    puts "ideal ready.0:    " + ideal_ready.to_s
    puts "ideal notready.2: " + ideal_not_ready.to_s
    num_tries = 600
    num_tries *= VALGRIND_TIMEOUT_MULTIPLIER if @valgrind
    for i in 0..num_tries do
      puts "wait_for_docs_moved(#{num_docs}): try=#{i})"
      stats = get_all_lid_stats
      print_corpus_hitcount(num_docs)
      if (!stable_stats(ideal_ready, stats[0]) ||
         !stable_stats(ideal_not_ready, stats[2]))
        sleep 2.0
      else
        break
      end
    end
    stats = get_all_lid_stats
    print_corpus_hitcount(num_docs)
    assert(stable_stats(ideal_ready, stats[0]) && stable_stats(ideal_not_ready, stats[2]))
  end

  def get_proton
    return vespa.search["search"].first
  end

  def get_memory_usage(attribute)
    uri = uri_escape("/documentdb/test/subdb/ready/attribute/#{attribute}", /[\[\]]?/)
    stats = vespa.search["search"].first.get_state_v1_custom_component(uri)
    stats["status"]["memoryUsage"]["allocatedBytes"].to_i
  end

  def test_lid_usage_metrics
    set_description("Test that document meta store metrics regarding lid usage is updated and reported")
    deploy_app(SearchApp.new.sd(SEARCH_DATA + "test.sd").allowed_lid_bloat(1000))
    start
    feed_puts(0, 400, true)
    assert_corpus_hitcount(400)
    assert_ready_and_removed(get_ideal_stats(400), get_ideal_stats(0))
    feed_removes(0, 400, 200, true)
    assert_corpus_hitcount(200)
    assert_ready_and_removed(LidUsageStats.new(401, 200, 1, 400, 0), get_ideal_stats(200))
    feed_puts(400, 400, true)
    assert_corpus_hitcount(600)
    assert_ready_and_removed(get_ideal_stats(600), get_ideal_stats(200))
    feed_removes(400, 800, 200, true)
    assert_corpus_hitcount(400)
    assert_ready_and_removed(LidUsageStats.new(601, 400, 1, 600, 0), get_ideal_stats(400))
  end

  def wait_and_verify_docs_moved(num_docs, exp_ready_stats, exp_removed_stats, exp_not_ready_stats = nil)
    wait_for_docs_moved(num_docs)
    metrics = get_metrics
    assert_lid_stats(exp_ready_stats, get_ready_stats(metrics))
    assert_lid_stats(exp_removed_stats, get_removed_stats(metrics))
    assert_lid_stats(exp_not_ready_stats, get_not_ready_stats(metrics)) if exp_not_ready_stats
    wait_for_corpus_hitcount(num_docs)
  end

  def restart_and_verify_docs_moved(num_docs, exp_ready_stats, exp_removed_stats)
    puts "#### Restart search node ####"
    vespa.search["search"].first.stop
    vespa.search["search"].first.start
    vespa.search["search"].wait_until_ready
    wait_and_verify_docs_moved(num_docs, exp_ready_stats, exp_removed_stats)
  end

  def flush_and_verify_docs_moved(num_docs, exp_ready_stats, exp_removed_stats)
    puts "#### Trigger flush and restart search node ####"
    vespa.search["search"].first.trigger_flush
    restart_and_verify_docs_moved(num_docs, exp_ready_stats, exp_removed_stats)
  end

  def feed_puts_and_removes(num_puts, num_removes)
    puts "#### Feed initial puts and removes ####"
    feed_puts(0, num_puts)
    feed_removes(0, num_puts, num_removes)
  end

  def feed_puts_updates_and_removes(num_puts, num_removes)
    puts "#### Feed initial puts, updates and removes ####"
    feed_puts(0, num_puts)
    feed_updates(0, num_puts)
    feed_removes(0, num_puts, num_removes)
  end

  def trigger_lid_compaction(two_nodes = false, disable_flush = false)
    puts "#### Redeploy app to trigger lid compaction ####"
    redeploy(get_app(0.2, two_nodes, disable_flush))
  end

  def wait_for_expected_end_stats(num_docs, num_removes)
    puts "#### Wait for expected end states ####"
    exp_ready_stats = get_ideal_stats(num_docs)
    exp_removed_stats = get_ideal_stats(num_removes)
    exp_not_ready_stats = get_ideal_stats(0)
    if (@ignore_lid_limit)
      exp_ready_stats.lid_limit = nil
      exp_not_ready_stats.lid_limit = nil
    end
    thread = Thread.new(self, num_docs, exp_ready_stats, exp_removed_stats, exp_not_ready_stats) do
      |my_self, my_num_docs, my_ready_stats, my_removed_stats, my_not_ready_stats|
      my_self.wait_and_verify_docs_moved(my_num_docs, my_ready_stats, my_removed_stats, my_not_ready_stats)
    end
    return thread
  end

  def test_basic_document_moving
    @valgrind = false
    set_description("Test that documents are moved to allow for lid space compaction")

    run_basic_document_moving_test(false)
  end

  def test_attribute_updates_are_preserved_during_document_moving
    @valgrind = false
    set_description("Test that attribute updates are preserved when moving documents during lid space compaction")

    run_basic_document_moving_test(true)
  end

  def run_basic_document_moving_test(feed_updates)
    deploy_app(get_app(0.0))
    start
    vespa.adminserver.logctl("searchnode:proton.server.maintenancecontroller", "debug=on")
    vespa.adminserver.logctl("searchnode:proton.documentmetastore.lid_allocator", "debug=on")

    num_docs = 100000
    num_removes = 40000
    num_remaining = num_docs - num_removes

    if feed_updates
      feed_puts_updates_and_removes(num_docs, num_removes)
    else
      feed_puts_and_removes(num_docs, num_removes)
    end

    exp_removed_stats = get_ideal_stats(num_removes)
    exp_ready_stats = get_ideal_stats(num_remaining)

    wait_and_verify_docs_moved(num_remaining, exp_ready_stats, exp_removed_stats)
    assert_log_matches(/.lidspace\.compaction\.complete.*documentsubdb":"test\.0\.ready.*lidlimit":60001/)

    restart_and_verify_docs_moved(num_remaining, exp_ready_stats, exp_removed_stats)

    flush_and_verify_docs_moved(num_remaining, exp_ready_stats, exp_removed_stats)
  end

  def test_document_moving_during_feed
    @valgrind = false
    set_description("Test that documents are moved during feed to allow for lid space compaction")
    deploy_app(get_app(2.0)) # no lid compaction will happen
    start
    vespa.adminserver.logctl("searchnode:proton.server.maintenancecontroller", "debug=on")

    num_docs_1 = 200000
    num_docs_2 = 100000
    num_removes = 50000
    num_remaining = num_docs_1 + num_docs_2 - num_removes
    gen_puts(num_docs_1, num_docs_2)

    feed_puts_and_removes(num_docs_1, num_removes)

    trigger_lid_compaction

    thread = wait_for_expected_end_stats(num_remaining, num_removes)

    puts "#### Feed puts ####"
    feed_puts(num_docs_1, num_docs_2)

    puts "#### Join verifying thread ####"
    thread.join

    restart_and_verify_docs_moved(num_remaining, get_ideal_stats(num_remaining), get_ideal_stats(num_removes))

    flush_and_verify_docs_moved(num_remaining, get_ideal_stats(num_remaining), get_ideal_stats(num_removes))
  end

   def test_document_moving_during_redistribution
    @valgrind = false
    set_description("Test that documents are moved during re-distribution to allow for lid space compaction")
    deploy_app(get_app(2.0, true)) # no lid compaction will happen
    start
    vespa.adminserver.logctl("searchnode:proton.server.maintenancecontroller", "debug=on")

    num_docs = 700000
    num_removes = 330000
    num_remaining = num_docs - num_removes
    # don't care about lid limit (~ 50% of num_remaining in ready and notready)
    @ignore_lid_limit = true

    feed_puts_and_removes(num_docs, num_removes)

    trigger_lid_compaction(true)

    thread = wait_for_expected_end_stats(num_remaining, num_removes)

    puts "#### Stop node 1 ####"
    stop_node_and_wait("search", 1)

    puts "#### Join verifying thread ####"
    thread.join
  end

  def test_shrink_memoryusage
    @valgrind = false
    set_description("Test that shrinking lid space reduces memory usage")
    deploy_app(get_app(2.0, false, true)) # no lid compaction will happen
    start
    num_docs = 10000
    num_removes = 5000
    num_remaining = num_docs - num_removes
    proton = get_proton
    proton.trigger_flush
    @gen_random_removes = true
    feed_puts_and_removes(num_docs, num_removes)

    f2memusage1 = get_memory_usage("f2")
    puts "attribute f2 memory usage before compaction is #{f2memusage1}"
    trigger_lid_compaction(false, true)

    exp_removed_stats = get_ideal_stats(num_removes)
    exp_ready_stats = get_ideal_stats(num_remaining)
    wait_and_verify_docs_moved(num_remaining, exp_ready_stats, exp_removed_stats)
    f2memusage2 = get_memory_usage("f2")
    puts "attribute f2 memory usage after compaction is #{f2memusage2}"
    assert(f2memusage2 == f2memusage1)

    for i in 1..30
      proton.trigger_flush
      f2memusage3 = get_memory_usage("f2")
      puts "try #{i} attribute f2 memory usage after flush is #{f2memusage3}"
      break if f2memusage3 < f2memusage2
      sleep 1.0
    end
    assert(f2memusage3 < f2memusage2)
  end

  def teardown
    stop
  end

end
