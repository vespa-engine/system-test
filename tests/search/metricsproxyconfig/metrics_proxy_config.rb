# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'nodetypes/yamas'

class MetricsProxyConfig < IndexedSearchTest

  include Yamas

  def setup
    set_owner("musum")
    set_description("Test metricsproxy config in services.xml")
  end

  def nightly?
    true
  end

  def test_metricproxy_config_simple
    deploy_app(SearchApp.new.
                   qrserver(QrserverCluster.new).
                   monitoring("yamastest", 60).
                   admin_metrics(Metrics.new.
                           consumer(Consumer.new("yamas").
                                   metric(Metric.new("peak_qps.average", "yamas_peak_qps")).
                                   metric(Metric.new("content.proton.documentdb.memory_usage.allocated_bytes.average", "memusage")).
                                   metric(Metric.new("content.proton.documentdb.documents.ready.last", "numdocs")).
                                   metric(Metric.new("documents_processed.rate", "indexing_docproc_documents_processed")))).
                   cluster(SearchCluster.new("music").
                               sd(SEARCH_DATA+"music.sd").
                               group(NodeGroup.new(0, "mygroup").
                                         node(NodeSpec.new("node1", 0)).
                                         node(NodeSpec.new("node1", 1)))))

    start_feed_wait_for_metrics

    container_name = "default"

    assert_metrics("yamastest.qrserver", ["yamas_peak_qps"], container_name)
    assert_metrics("yamastest.searchnode", ["memusage", "numdocs"], "music")
    assert_metrics("yamastest.qrserver", ["indexing_docproc_documents_processed"], container_name)

    vespa.stop_base

    #deploy new app with other metrics, check that eveything gets updated.
    deploy_app(SearchApp.new.
                   qrserver(QrserverCluster.new).
                   monitoring("yamastest", 60).
                   admin_metrics(Metrics.new.
                           consumer(Consumer.new("yamas").
                                   metric(Metric.new("content.proton.executor.flush.maxpending.count", "maxpending")))).
                   cluster(SearchCluster.new("music").
                               sd(SEARCH_DATA+"music.sd").
                               num_parts(2)))

    start_feed_wait_for_metrics

    assert_metrics("yamastest.qrserver", ["peak_qps.max"], container_name)
    assert_metrics("yamastest.searchnode", ["maxpending", "content.proton.documentdb.documents.total.last"], "music")
    assert_metrics("yamastest.qrserver", ["documents_processed.rate"], container_name)
  end

  def test_metricproxy_slingstone_config
    deploy_app(SearchApp.new.
                   qrserver(QrserverCluster.new).
                   admin_metrics(Metrics.new.
                                 consumer(Consumer.new("foo").
                                          metric(Metric.new("serverActiveThreads.average", "my.active.threads")).
                                          metric(Metric.new("content.proton.executor.flush.maxpending.count", "flush.maxpending")))).
                   cluster(SearchCluster.new("music").
                               sd(SEARCH_DATA+"music.sd").
                               group(NodeGroup.new(0, "mygroup").
                                         node(NodeSpec.new("node1", 0)).
                                         node(NodeSpec.new("node1", 1)))))

    start_feed_wait_for_metrics

    assert_metrics("vespa.qrserver", ["my.active.threads"], "default")
    assert_metrics("vespa.searchnode", ["flush.maxpending"], "music")
    # also original metric for original consumer
    assert_metrics("vespa.qrserver", ["serverActiveThreads.average"], "default")

    # check that yamas routing namespaces are correct
    msgs = get_yamas_metrics_yms(vespa.adminserver, "vespa.qrserver")
    assert_metric_in_namespace(msgs, 'Vespa', 'serverActiveThreads.average')
    assert_metric_not_in_namespace(msgs, 'foo', 'serverActiveThreads.average')
    assert_metric_in_namespace(msgs, 'foo', 'my.active.threads')
    assert_metric_not_in_namespace(msgs, 'Vespa', 'my.active.threads')
    assert_status(msgs)
  end

  def get_namespace_metric(messages, namespace, metricname)
    messages.each do |m|
      next unless m.key?('routing') # Skip the status block
      namespaces = m['routing']['yamas']['namespaces']
      namespaces.each do |ns|
        if ns == namespace && m['metrics']
          m['metrics'].each do |k,v|
            return "#{k} => #{v}" if (k == metricname)
          end
        end
      end
    end
    return nil
  end

  def assert_metric_in_namespace(messages, namespace, metricname)
    m = get_namespace_metric(messages, namespace, metricname)
    puts "Metric #{metricname} in namespace #{namespace}: #{m}"
    assert(m)
  end

  def assert_metric_not_in_namespace(messages, namespace, metricname)
    m = get_namespace_metric(messages, namespace, metricname)
    puts "Metric #{metricname} in namespace #{namespace}: #{m}"
    assert(!m)
  end

  def start_feed_wait_for_metrics
    start
    # metrics for qrserver are not generated if there is no traffic
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.xml")
    puts "Wait 70s for metrics"
    sleep 70
  end

  def assert_metrics(system_name, expected_metric_names, instance)
    messages = get_yamas_metrics_yms(vespa.adminserver, system_name)
    assert_status(messages)
    expected_metric_names.each do |name|
      puts "Looking for metric #{name}"
      assert(get_metric(messages, name, false, {'clustername' => instance}))
    end
  end

  def get_status_block(messages)
    status_blocks = messages.select{ | m | m.key?('status_code') }
    assert_equal(1, status_blocks.count, "There should be only 1 status block, found #{status_blocks.count}")
    status_blocks.first
  end

  def assert_status(msgs)
    status_block = get_status_block(msgs)
    assert_equal(0, status_block['status_code'])
  end
  
  def teardown
    stop
  end
end
