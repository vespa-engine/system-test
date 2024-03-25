# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class MetricsProxy < IndexedStreamingSearchTest

  def setup
    set_owner("bergum")
    set_description("Test metrics proxy functionality")
  end

  def make_app
    SearchApp.new.
      sd(SEARCH_DATA+'music.sd').
      container(Container.new.
                  documentapi(ContainerDocumentApi.new).
                  search(Searching.new))
  end

  def test_metricsproxy
    deploy_app(make_app)
    start
    puts vespa.metricsproxies.inspect
    wrapper = vespa.metricsproxies.values.first.get_wrapper
    services = {}
    wrapper.getServices[0].split(" ").each do |service|
      services[service] = 1
    end

    assert(services['searchnode'])
    assert(services['container'])
  end

  def test_http_rest_api
    deploy_app(make_app)
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
    assert(services.count > 0, services)

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
    ignored_just_for_caching = container.search("/metrics/v2/values", port)
    sleep 2 # Give time for metrics to be fetched and cached.
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
    assert(services.count > 0, services)

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
        if m['application'] == 'vespa_app.container' and m['dimensions']['metrictype'] == 'system'
          found = true
          assert(m['metrics']['memory_virt'] > 0, "memory_virt should be more than zero")
          assert(m['metrics']['memory_rss'] > 0, "memory_virt should be more than zero")
          assert(m['metrics']['cpu'] > 0.0, "cpu usage should be higher than 0.0") if check_cpu
        end
      end
      assert(found, "System metrics for container should be found")
    end
    deploy_app(make_app.
                 monitoring("vespa_app", 60))
    start
    puts "Wait 70s for system metrics snapshot"
    sleep 70
    metrics = get_metrics('vespa_app.container')
    # Cpu utilization will mostly likely not have been collected yet
    check(metrics, false)
    puts "Wait 70s for another system metrics snapshot"
    sleep 70
    metrics = get_metrics('vespa_app.container')
    # After two intervals we should have cpu utilization
    check(metrics, true)
  end

  def get_metrics(monitoring_service_name)
    wrapper = vespa.metricsproxies.values.first.get_wrapper
    JSON.parse(wrapper.getMetricsForYamas(monitoring_service_name)[0])
  end 

  def teardown
    stop
  end
end
