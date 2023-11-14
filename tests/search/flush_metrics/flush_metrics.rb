# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_search_test' 
require 'search/utils/elastic_doc_generator'

class FlushMetricsTest < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def feed_docs
    feed_file = dirs.tmpdir + "feed.xml"
    ElasticDocGenerator.write_docs(0, 10, feed_file)
    feed_and_wait_for_docs("test", 10, :file => feed_file)
  end

  def get_flush_metric(metrics, name)
    full_name = "content.proton.documentdb.job.#{name}"
    metric = metrics.get_all(full_name)
    assert_equal("test", metric["dimensions"]["documenttype"])
    value = metric["values"]["average"]
    puts "#{full_name}['average']=#{value}"
    return value
  end

  def assert_flush_metrics(metrics, predicate)
    assert(predicate.call(get_flush_metric(metrics, "attribute_flush")))
    assert(predicate.call(get_flush_metric(metrics, "memory_index_flush")))
    assert(predicate.call(get_flush_metric(metrics, "disk_index_fusion")))
    assert(predicate.call(get_flush_metric(metrics, "document_store_flush")))
    assert(predicate.call(get_flush_metric(metrics, "document_store_compact")))
  end

  def test_flush_metrics
    set_description("Test that flush (job) metrics are reported")
    deploy_app(SearchApp.new.sd(SEARCH_DATA + "test.sd"))
    start
    feed_docs

    search_node = vespa.search["search"].first
    metrics = search_node.get_total_metrics
    assert_flush_metrics(metrics, lambda { |average| average == 0.0 })

    search_node.trigger_flush
    metrics = search_node.get_total_metrics
    assert_flush_metrics(metrics, lambda { |average| average > 0.0 })
  end

  def teardown
    stop
  end

end
