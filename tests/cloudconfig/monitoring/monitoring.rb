# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'json'
require 'nodetypes/yamas'

class MonitoringTest < CloudConfigTest
  include Yamas

  def setup
    @node = @vespa.nodeproxies.first[1]
    @hostname = @vespa.nodeproxies.first[0]
    @httpport = 19071
    @metrics_fetcher = nil
  end

  def test_metricsproxy_metrics
    set_owner("musum")
    set_description("Test that metrics can be found by metrics proxy")
    @metrics_fetcher = method(:get_metricsproxy_metric)
    do_deploy
    start
    check_metrics
  end

  def do_deploy
    deploy_app(CloudconfigApp.new.
                    monitoring("yamastest", 60).
                    admin_metrics(Metrics.new.
                            consumer(Consumer.new("yamas").
                                    metric(Metric.new("configserver.activeSessions.last", "configserver.activeSessions")))))
  end

  # NOTE: Whenever you add a new metric check here, remember to update the deployed app with metrics so that metrics proxy can pick them up.
  def check_metrics
    assert_metric_gt(0, "configserver.requests.count", "default", "default")
    assert_metric_gt(0, "configserver.latency.average", "default", "default")
    # TODO: Does not work because http handler does not increase failure metric.
    # assert_metric_gt(0, "configserver.failedRequests", "default", "default")

    do_deploy
    assert_metric_equal(1, "configserver.hosts.last", "default", "default")
    assert_metric_equal(1, "configserver.activeSessions", "default")

    assert_metric_gt(0, "configserver.cacheConfigElems.last", "default", "default")
    assert_metric_gt(0, "configserver.cacheChecksumElems.last", "default", "default")
    # assert_metric_equal(1, "configserver.delayedResponses", "default", "default")
  end

  def assert_metric_equal(expectedValue, metricName, tenantName=nil, applicationName=nil)
    assert_equal(expectedValue, @metrics_fetcher.call(metricName, tenantName, applicationName).to_i)
  end

  def assert_metric_gt(lower, metricName, tenantName=nil, applicationName=nil)
    assert(@metrics_fetcher.call(metricName, tenantName, applicationName) > lower)
  end

  def run_requests
    get_config_v2_assert_200(@hostname, "default", "default", "default", "cloud.config.log.logd", "admin")
    # Trying to increase failures metric
    get_config_v2(@hostname, "default", "default", "default", "non-existent.config", "admin")
  end

  def get_metricsproxy_metric(name, tenant=nil, application=nil, timeout=120)
    endtime = Time.now.to_i + timeout
    while (Time.now.to_i < endtime)
      run_requests
      messages = get_yamas_metrics_yms(@node, "yamastest.configserver")
      messages.each do |msg|
        dimensions = msg["dimensions"]
        metrics = msg["metrics"]
        if (metrics != nil && dimensions != nil)
          tenantKey = dimensions["tenantName"]
          appKey = dimensions["applicationName"]
          if ((tenant == nil || tenantKey == tenant) && (application == nil || appKey == application) && metrics != nil && metrics[name] != nil)
            m = metrics[name].to_f
            return m
          end
        end
      end
      sleep 2
    end
    raise "Unable to find metric '#{name}' for tenant '#{tenant}' and application '#{application}'"
  end

  def teardown
    stop
  end

end
