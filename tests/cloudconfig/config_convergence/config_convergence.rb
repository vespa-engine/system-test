# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'app_generator/search_app'
require 'json'

class ConfigConvergence < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Tests config convergence API")
    @node = @vespa.nodeproxies.first[1]
  end

  def test_config_convergence
    output = deploy_app(SearchApp.new.sd(SEARCH_DATA + "music.sd"))
    config_generation = get_generation(output).to_i
    start

    # Service list
    response = service_list_config_converge(@node.hostname)
    assert_equal(200, response.code.to_i)
    json = get_json(response)
    assert_equal(config_generation, json["wantedGeneration"])
    services = json["services"]
    # 7 services: container, container-clustercontroller, distributor, logserver-container, metricsproxy-container, storagenode, searchnode
    assert_equal(7, services.length)

    converged_services = wait_for_services_to_converge(services)
    # All converged, check result for each service
    converged_services.each_pair { |url, json|
      assert_response_for_converged_service(url, config_generation, json)
    }

    @vespa.container.values.first.stop
    response = get_converged_status_for_servicetype("container")
    assert_response_code(response, 404)
    json = get_json(response)
    assert_match(/Connection refused/, json["error"])

    @vespa.container.values.first.start
    wait_for_services_to_converge(services)
    response = get_converged_status_for_servicetype("container")
    assert_response_code(response, 200)
    json = get_json(response)
    assert_response_for_converged_service(json["url"], config_generation, json)
    assert_nil(json["error"])
  end

  def service_list_config_converge(hostname, tenant="default", application="default", instance="default", env="prod", region="default")
    url = "http://#{hostname}:19071/application/v2/tenant/#{tenant}/application/#{application}/environment/#{env}/region/#{region}/instance/#{instance}/serviceconverge"
    http_request_get(URI(url))
  end

  def service_config_converge(url)
    http_request_get(URI(url))
  end

    # Check that each service has converged and store result with url as key
  def wait_for_services_to_converge(services)
    converged_services = Hash.new
    1.upto(120) {
      services.each do |service|
        url = service["url"]
        result = get_json(service_config_converge(url))
        if result["converged"]
          converged_services[url] = result
        end
      end
      break if converged_services.size == services.length
      sleep 1
    }
    assert(converged_services.size == services.length,
           "Not all services converged:\n #{print_non_converged_services(converged_services, services)}")
    converged_services
  end


  def print_non_converged_services(converged_services, all_services)
    all_services.each do |service|
      unless converged_services.has_key?(service["url"])
        puts "Service at #{service} did not converge\n"
      end
    end
  end

  # Assumes only one service of the type supplied
  def get_converged_status_for_servicetype(type)
    response = service_list_config_converge(@node.hostname)
    json = get_json(response)
    json["services"].each do |service|
      url = service["url"]
      if service["type"] == type
        return service_config_converge(service["url"])
      end
    end
    nil
  end

  def assert_response_for_converged_service(url, config_generation, json)
      assert_equal(config_generation, json["wantedGeneration"])
      assert_equal(config_generation, json["currentGeneration"])
      assert_equal(url, json["url"])
  end

  def teardown
    stop
  end
end
