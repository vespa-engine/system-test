# Copyright Vespa.ai. All rights reserved.
require 'app_generator/container_app'
require 'search_container_test'
require 'json'

class HealthMonitor < SearchContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Test that container health status page is served")
    deploy_app(ContainerApp.new.
               container(Container.new.
                         config(ConfigOverride.new("container.jdisc.config.health-monitor").
                                add("snapshot_interval", "10"))))
    start
  end

  def test_container_health_monitor_serving
    node = vespa.container.values.first;
    Timeout::timeout(500) {
      while !checkHealthData
        node.http_get("localhost", 0, "/status.html")
        sleep 1
      end
    }
  end

  def checkHealthData
    result = vespa.container.values.first.http_get("localhost", 0, "/state/v1/health")
    json = result.body
    puts "http_get('/state/v1/health'): #{json}"

    data = JSON.parse(result.body)
    assert(data.has_key? "status")
    assert(data["status"].has_key? "code")
    assert_equal("up", data["status"]["code"])
    assert(data.has_key? "metrics")
    if !data["metrics"].has_key? "snapshot"
        return false
    end
    assert(data["metrics"]["snapshot"].has_key? "from")
    assert(data["metrics"]["snapshot"].has_key? "to")
    if (!(data["metrics"].has_key? "values"))
      return false
    end
    if (data["metrics"]["values"].empty?)
      return false
    end
    return true
  end

  def teardown
    stop
  end

end
