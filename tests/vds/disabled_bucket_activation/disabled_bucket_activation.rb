# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class DisabledBucketActivationTest < VdsTest

  def setup
    set_owner('vekterli')
    set_description('Test that running Proton in non-indexed mode ' +
                    'inhibits activation of buckets')
  end

  def non_indexed_proton_app(with_streaming: false)
    app = default_app_no_sd.sd(SEARCH_DATA + 'music.sd').
              num_nodes(2).redundancy(2).
              provider('PROTON').
              distribution_bits(16)
    if with_streaming
      app.streaming
    end
    app
  end

  def content_cluster
    vespa.storage['storage']
  end

  def ensure_node_metric_is_zero(node, metric_name)
    metric_data = node.get_metrics_matching(Regexp.quote(metric_name))[metric_name]
    if metric_data.nil?
      raise "Metric #{metric_name} did not exist on node #{node.index}"
    end
    last_value = metric_data['last']
    if last_value != 0
      raise "Expected last value of zero for metric #{metric_name}" +
            " on node #{node.index}, was #{last_value}"
    end
  end

  def force_bucket_bucket_activation_to_take_place_if_enabled
    # Take down a node to force a scenario where activation would have taken
    # place unless inhibition were in place.
    vespa.stop_content_node('storage', 0)
    content_cluster.wait_until_ready
    vespa.start_content_node('storage', 0)
    content_cluster.wait_until_ready
  end

  def do_test_bucket_activation_is_disabled(app)
    deploy_app(app)
    start

    feed(:file => SEARCH_DATA + 'music.10.json')

    force_bucket_bucket_activation_to_take_place_if_enabled

    metrics = ['vds.datastored.alldisks.activebuckets',
               'content.proton.documentdb{documenttype:music}.documents.active']

    content_cluster.storage.each do |key, node|
      metrics.each{|metric| ensure_node_metric_is_zero(node, metric) }
    end
  end

  def test_proton_store_only_mode_inhibits_bucket_activation
    do_test_bucket_activation_is_disabled(non_indexed_proton_app(with_streaming: false))
  end

  def test_proton_streaming_mode_inhibits_bucket_activation
    do_test_bucket_activation_is_disabled(non_indexed_proton_app(with_streaming: true))
  end

  def teardown
    stop
  end

end
