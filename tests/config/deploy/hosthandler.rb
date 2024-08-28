# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'app_generator/config_app'
require 'json'

class HostHandler < CloudConfigTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("musum")
    set_description("Tests host handler in v2 application API")
    setup_test
  end

  def can_share_configservers?
    true
  end

  def setup_test
    @tenant_name = "mytenant"
    @application_name = "default"
    @environment = "prod"
    @region = "default"
    @instance = "default"
    deploy_app(ConfigApp.new)
    @configserver = configserverhostlist[0]
    puts "configserver=#{@configserver}"
  end

  def test_get_application_for_host
    @hostname = "unknown"
    result = get_host_info(@configserver, @hostname)
    assert_not_found(result, @hostname)

    @hostname = vespa.nodeproxies.first[0]
    result = get_host_info(@configserver, @hostname)
    assert_host_response_code_and_body(200, result)

    # delete application, check that host is removed from host registry
    delete_application_v2(@configserver, @tenant_name, @application_name)
    result = get_host_info(@configserver, @hostname)
    assert_not_found(result, @hostname)
  end

  def assert_host_response_code_and_body(expected_response_code, result)
    assert_equal(expected_response_code, result.code.to_i)
    puts "response=#{result.body}"
    assert_equal(@tenant_name, JSON.parse(result.body)["tenant"])
    assert_equal(@application_name, JSON.parse(result.body)["application"])
    assert_equal(@environment, JSON.parse(result.body)["environment"])
    assert_equal(@region, JSON.parse(result.body)["region"])
    assert_equal(@instance, JSON.parse(result.body)["instance"])
  end

  def assert_not_found(result, hostname)
    assert_equal(404, result.code.to_i)
    puts "response=#{result.body}"
    assert_equal("Could not find any application using host '#{hostname}'", JSON.parse(result.body)["message"])
  end

  def teardown
    stop
    delete_tenant_and_its_applications(@configserver, @tenant_name)
  end

end
