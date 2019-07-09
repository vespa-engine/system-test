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
    assert(services['topleveldispatch'])
  end

  def test_http_rest_api
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    container = @vespa.container.values.first
    result = container.search("/metrics/v1/values", 19092)
    json = result.json

    assert(json.has_key? 'services')
    services = json['services']
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

  def test_ysar
    @valgrind = false
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    node = vespa.nodeproxies.values.first

    groups = wait_for_service_in_ysar_output(node, "searchnode1", "searchnode2")
    wait_for_reconfig

    vespa.stop_base
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").num_parts(2))
    vespa.start_base

    groups = wait_for_service_in_ysar_output(node, "searchnode1")
    groups = wait_for_service_in_ysar_output(node, "searchnode2")
    wait_for_reconfig  # Libyell does not like to be taken down when it is getting up.

    vespa.stop_base
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    vespa.start_base

    groups = wait_for_service_in_ysar_output(node, "searchnode1", "searchnode2")
  end

  def ysar_groups(node)
    ret = node.execute('ysar -h', :exitcode => true)
    groups_string = ret[1]

    groups = {}
    groups_string.split("\n").each do |line|
      if line =~ /^\s+-(\w+)\s+(.*)/
        group = $1
        text = $2
        groups[group] = text
      end
    end

    groups
  end

   # Wait for new ysar plugins to be written to ysar plugins
   # directory. Check for services that should be in output or services
   # that should _not_ be in output
  def wait_for_service_in_ysar_output(node, service_in_output, service_not_in_output=nil)
    time = 0
    groups = nil
    loop do 
      sleep 1
      time = time + 1
      groups =  ysar_groups(node)

      in_ok = true
      if service_in_output
        in_ok = false
        in_ok = groups[service_in_output]
      end

      out_ok = true
      if service_not_in_output
        out_ok = false
        out_ok = !groups[service_not_in_output]
      end

      break if  time > 70 || (in_ok && out_ok)  # Wait for interval + 10 secs max
    end
  end

  def get_metrics(yamas_service_name)
    wrapper = vespa.metricsproxies.values.first.get_wrapper
    JSON.parse(wrapper.getMetricsForYamas(yamas_service_name)[0])
  end 

  def teardown
    stop
  end
end
