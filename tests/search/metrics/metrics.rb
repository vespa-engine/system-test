# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'indexed_only_search_test'
require 'pp'
require 'base64'

class SearchMetrics < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
  end

  def test_metrics
    set_description("Check reporting of metrics")
    deploy_app(SearchApp.new.cluster(SearchCluster.new('test').
                      sd(selfdir + "test.sd").
                      tune_searchnode({:summary => {:store => {:cache => { :maxsize => 8192,
                                                                           :compression => {:type => :lz4, :level => 8}
                                                                         } } } }).
                 search_io('DIRECTIO').posting_list_cache(262144)))
    start

    # Search handler does a warmup query which may or may not hit the backend, since 8.170. We need to account for this in some search metrics below. 
    search_count_bias = vespa.search["test"].first.get_total_metrics.get("content.proton.search_protocol.query.latency")["count"]

    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.json")
    assert_hitcount("f1:c", 2)
    assert_hitcount("f1:xyzzy", 0)

    metrics = vespa.search["test"].first.get_total_metrics
    # dump_metric_names(metrics)

    # ported from test doing xml grepping to verify metric counts
    assert_equal(1, metrics.extract(/^content[.]proton[.]documentdb[.]documents[.]ready$/).size,
                 "There should only be one documentdb.")
    assert_equal(1, metrics.extract(/^content[.]proton[.]documentdb[.]matching[.]queries$/).size,
                 "There should only be one 'matching' tag.")
    assert_equal(2, metrics.extract(/^content[.]proton[.]documentdb[.]matching[.]rank_profile[.]queries$/).size,
                 "There should be 2 rank profiles with separate metrics")
    assert_equal(8, metrics.extract(/^content[.]proton[.]documentdb[.]matching[.]rank_profile[.]docid_partition[.]active_time$/).size,
                 "There should be 2 rank profiles with 4 separate metrics per thread")
    assert_equal(1, metrics.extract(/^content[.]proton[.]documentdb[.]ready[.]document_store[.]disk_usage$/).size,
                 "There should be 1 ready document store")
    assert_equal(1, metrics.extract(/^content[.]proton[.]documentdb[.]notready[.]document_store[.]disk_usage$/).size,
                 "There should be 1 notready document store")
    assert_equal(1, metrics.extract(/^content[.]proton[.]documentdb[.]removed[.]document_store[.]disk_usage$/).size,
                 "There should be 1 removed document store")

    # documents metrics
    assert_equal(2, get_last("content.proton.documentdb.documents.ready", metrics))
    assert_equal(2, get_last("content.proton.documentdb.documents.active", metrics))
    assert_equal(2, get_last("content.proton.documentdb.documents.total", metrics))
    assert_equal(1, get_last("content.proton.documentdb.documents.removed", metrics))

    # resource usage metrics
    assert(metrics.get("content.proton.resource_usage.disk")["last"] > 0)
    assert(metrics.get("content.proton.resource_usage.memory")["last"] > 0)
    assert_equal(0, metrics.get("content.proton.resource_usage.feeding_blocked")["last"])

    assert_equal(9, metrics.get("content.proton.transactionlog.entries")["last"])

    # query / docsum metrics
    assert_equal(3, metrics.get("content.proton.search_protocol.query.latency")["count"] - search_count_bias)
    assert_equal(1, metrics.get("content.proton.search_protocol.docsum.latency")["count"])

    # matching metrics
    assert_equal(3, metrics.get("content.proton.documentdb.matching.queries",
                                {"documenttype" => "test"})["count"] - search_count_bias)
    assert_equal(3, metrics.get("content.proton.documentdb.matching.rank_profile.queries",
                                {"documenttype" => "test", "rankProfile" => "default"})["count"])
    assert_equal(3, metrics.get("content.proton.documentdb.matching.rank_profile.docid_partition.active_time",
                                {"documenttype" => "test", "rankProfile" => "default", "docidPartition" => "docid_part03"})["count"])

    # document store cache metrics
    assert_equal(2, get_last("content.proton.documentdb.ready.document_store.cache.elements", metrics))
    assert_equal(418, get_last("content.proton.documentdb.ready.document_store.cache.memory_usage", metrics))
    assert_equal(3, get_count("content.proton.documentdb.ready.document_store.cache.lookups", metrics))
    assert_equal(1, get_count("content.proton.documentdb.ready.document_store.cache.invalidations", metrics))
    assert_equal(3, get_count("content.proton.documentdb.ready.document_store.cache.hit_rate", metrics))

    assert_document_db_total_memory_usage(metrics)
    assert_document_db_total_disk_usage(metrics)
    assert_document_db_attribute_memory_usage(metrics)

    flush_memory_index
    sleep 1 # Wait for disk index to be used for search
    assert_hitcount("f1:c", 2)
    metrics = vespa.search['test'].first.get_total_metrics # Get metrics containing disk index
    assert_document_db_size_on_disk(metrics)
    assert_document_db_disk_io(metrics)
    assert_document_db_cached_disk_io(metrics, false)
    assert_hitcount("f1:c", 2)
    metrics = vespa.search['test'].first.get_total_metrics # Get metrics containing disk index
    assert_document_db_disk_io(metrics)
    assert_document_db_cached_disk_io(metrics, true)
  end

  def test_metrics_imported_attributes
    set_description("Check reporting of metrics with imported attributes")
    deploy_app(SearchApp.new.cluster(SearchCluster.new('test').
                      sd(selfdir + "parent.sd", { :global => true }).
                      sd(selfdir + "child.sd")))
    start
    metrics = vespa.search["test"].first.get_total_metrics
    assert_equal(2, metrics.extract(/^content[.]proton[.]documentdb[.]documents[.]ready$/).size,
                 "There should be two documentdbs.")
    assert(1000 < get_parent_attribute_memory_usage("f3", metrics))
    assert(100 < get_child_attribute_memory_usage("my_f3", metrics))
  end

  def assert_document_db_total_memory_usage(metrics)
    exp_total = get_document_store_memory_usage("ready", metrics)
    exp_total += get_document_store_memory_usage("notready", metrics)
    exp_total += get_document_store_memory_usage("removed", metrics)
    exp_total += get_last("content.proton.documentdb.index.memory_usage.allocated_bytes", metrics)
    exp_total += get_last("content.proton.documentdb.attribute.memory_usage.allocated_bytes", metrics)

    act_total = get_last("content.proton.documentdb.memory_usage.allocated_bytes", metrics)
    assert_equal(exp_total, act_total)
    puts "act_total = " + act_total.to_s
    assert(act_total > 1000000)
  end

  def get_document_store_memory_usage(subdb, metrics)
    result = get_last("content.proton.documentdb.#{subdb}.document_store.memory_usage.allocated_bytes", metrics)
    result += get_last("content.proton.documentdb.#{subdb}.document_store.cache.memory_usage", metrics)
    result
  end

  def assert_document_db_total_disk_usage(metrics)
    exp_total = get_document_store_disk_usage("ready", metrics)
    exp_total += get_document_store_disk_usage("notready", metrics)
    exp_total += get_document_store_disk_usage("removed", metrics)
    exp_total += get_last("content.proton.documentdb.index.disk_usage", metrics)

    act_total = get_last("content.proton.documentdb.disk_usage", metrics)
    assert_equal(exp_total, act_total)
    assert(act_total > 14000)
  end

  def get_document_store_disk_usage(subdb, metrics)
    get_last("content.proton.documentdb.#{subdb}.document_store.disk_usage", metrics)
  end

  def assert_document_db_attribute_memory_usage(metrics)
    assert(1000 < get_attribute_memory_usage("ready", "[documentmetastore]", metrics));
    assert(1000 < get_attribute_memory_usage("ready", "f2", metrics));
    assert(1000 < get_attribute_memory_usage("notready", "[documentmetastore]", metrics));
  end

  def get_attribute_memory_usage(subdb, attr_name, metrics)
    metrics.get("content.proton.documentdb.#{subdb}.attribute.memory_usage.allocated_bytes",
                {"documenttype" => "test", "field" => attr_name})["last"]
  end

  def get_parent_attribute_memory_usage(attr_name, metrics)
    metrics.get("content.proton.documentdb.ready.attribute.memory_usage.allocated_bytes",
                {"documenttype" => "parent", "field" => attr_name})["last"]
  end

  def get_child_attribute_memory_usage(attr_name, metrics)
    metrics.get("content.proton.documentdb.ready.attribute.memory_usage.allocated_bytes",
                {"documenttype" => "child", "field" => attr_name})["last"]
  end

  def get_last(name, metrics)
    metrics.get(name, {"documenttype" => "test"})["last"]
  end

  def get_count(name, metrics)
    metrics.get(name, {"documenttype" => "test"})["count"]
  end

  def flush_memory_index
    vespa.search['test'].first.trigger_flush
    wait_for_log_matches(/.*flush\.complete.*memoryindex\.flush/, 1)
  end

  def assert_document_db_size_on_disk(metrics)
    f1_size_on_disk = get_size_on_disk_for_field('f1', metrics)
    puts "f1_size_on_disk = " + f1_size_on_disk.to_s
    assert(1000 < f1_size_on_disk)
    f2_size_on_disk = get_size_on_disk_for_attribute_field('f2', metrics)
    puts "f2_size_on_disk = " + f2_size_on_disk.to_s
    assert(1000 < f2_size_on_disk)
  end

  def assert_document_db_disk_io(metrics)
    f1_disk_io = get_disk_io_for_field('f1', metrics)
    puts "f1_disk_io = " + f1_disk_io.to_s
    assert(1000 < f1_disk_io["sum"])
    assert(0 < f1_disk_io["count"])
  end

  def assert_document_db_cached_disk_io(metrics, expect_cached)
    f1_cached_disk_io = get_cached_disk_io_for_field('f1', metrics)
    puts "f1_cached_disk_io = " + f1_cached_disk_io.to_s
    posting_list_cache_hit_rate = get_postinglist_cache_hit_rate(metrics)
    puts "posting_list_cache_hit_rate = " + posting_list_cache_hit_rate.to_s
    if expect_cached
      assert(10 < f1_cached_disk_io["sum"])
      assert(0 < f1_cached_disk_io["count"])
      assert(0 < posting_list_cache_hit_rate)
    else
      assert_equal(0, f1_cached_disk_io["sum"])
      assert_equal(0, f1_cached_disk_io["count"])
      assert_equal(0, posting_list_cache_hit_rate)
    end
  end

  def get_size_on_disk_for_field(field_name, metrics)
    metrics.get('content.proton.documentdb.ready.index.size_on_disk',
                {"documenttype" => "test", "field" => field_name})["last"]
  end


  def get_disk_io_for_field(field_name, metrics)
    metrics.get('content.proton.documentdb.ready.index.io.search.read_bytes',
                {"documenttype" => "test", "field" => field_name})
  end

  def get_cached_disk_io_for_field(field_name, metrics)
    metrics.get('content.proton.documentdb.ready.index.io.search.cached_read_bytes',
                {"documenttype" => "test", "field" => field_name})
  end

  def get_postinglist_cache_hit_rate(metrics)
    metrics.get('content.proton.index.cache.postinglist.hit_rate')['last']
  end

  def get_size_on_disk_for_attribute_field(field_name, metrics)
    metrics.get('content.proton.documentdb.ready.attribute.size_on_disk',
                {"documenttype" => "test", "field" => field_name})["last"]
  end

  def dump_metric_names(metrics)
    metrics.json["values"].each do |metric|
      name = metric["name"]
      dimensions = metric["dimensions"]
      puts "#{name} (#{dimensions.to_a})"
    end
  end

  def teardown
    stop
  end

end
