# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MetricsProxy < IndexedSearchTest

  def setup
    set_owner("bergum")
    set_description("Test metrics proxy functionality")
  end

  def test_metricsproxy
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").qrserver(QrserverCluster.new))
    start
    puts vespa.metricsproxies.inspect
    wrapper = vespa.metricsproxies.values.first.get_wrapper
    services = {}
    wrapper.getServices[0].split(" ").each do |service|
      services[service] = 1
    end

    assert(services['searchnode'])
    assert(services['qrserver'])
  end

  def test_http_rest_api
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    container = @vespa.container.values.first
    verify_metrics_v1_api(container)
    verify_metrics_v2_api(container, 19092)
    verify_metrics_v2_api(container, container.http_port)
    verify_prometheus_v1_api(container)
  end

  def verify_metrics_v1_api(container)
    result = container.search("/metrics/v1/values", 19092)
    json = result.json

    assert(json.has_key? 'services')
    services = json['services']
    assert(services.size > 0)

    services.each do |service|
      assert(service.has_key? 'name')
      assert(service.has_key? 'status')
      status = service['status']
      assert(status.has_key? 'code')
      assert_equal("up", status['code'])
      assert(service.has_key? 'metrics')
    end
  end

  def verify_metrics_v2_api(container, port)
    puts "Verifying metrics/v2 on port #{port}"
    result = container.search("/metrics/v2/values", port)
    json = result.json

    assert(json.has_key? 'nodes')
    nodes = json['nodes']
    assert(nodes.size == 1)
    node = nodes[0]

    assert(node.has_key? 'hostname')
    assert(node.has_key? 'role')
    assert(node.has_key? 'services')

    services = node['services']
    assert(services.count > 0)

    services.each do |service|
      assert(service.has_key? 'name')
      assert(service.has_key? 'status')
      status = service['status']
      assert(status.has_key? 'code')
      assert_equal("up", status['code'])
      assert(service.has_key? 'metrics')
    end
  end

  def verify_prometheus_v1_api(container)
    puts "Verifying prometheus/v1 on #{container.http_port}"
    result = container.http_get2("/prometheus/v1/values").body

    # Just verify that a couple of metrics are present
    assert_match(Regexp.new("# HELP serverActiveThreads_average"), result, "Could not find serverActiveThreads_average metric.")
    assert_match(Regexp.new("# HELP memory_rss"), result, "Could not find memory_rss metric.")
  end

  def test_system_metrics
    set_description("Ensure new system metrics snapshots does not keep old system metrics")
    def check(metrics, check_cpu)
      found = false
      metrics['metrics'].each do  |m|
        if m['application'] == 'yamastest.qrserver' and m['dimensions']['metrictype'] == 'system'
          found = true
          assert(m['metrics']['memory_virt'] > 0, "memory_virt should be more than zero")
          assert(m['metrics']['memory_rss'] > 0, "memory_virt should be more than zero")
          assert(m['metrics']['cpu'] > 0.0, "cpu usage should be higher than 0.0") if check_cpu
        end
      end
      assert(found, "System metrics for qrserver should be found")
    end
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
        qrserver(QrserverCluster.new).
        monitoring("yamastest", 60))
    start
    puts "Wait 70s for system metrics snapshot"
    sleep 70
    metrics = get_metrics('yamastest.qrserver')
    # Cpu utilization will mostly likely not have been collected yet
    check(metrics, false)
    puts "Wait 70s for another system metrics snapshot"
    sleep 70
    metrics = get_metrics('yamastest.qrserver')
    # After two intervals we should have cpu utilization
    check(metrics, true)
  end

  def get_metrics(yamas_service_name)
    wrapper = vespa.metricsproxies.values.first.get_wrapper
    JSON.parse(wrapper.getMetricsForYamas(yamas_service_name)[0])
  end 

  def teardown
    stop
  end
end
