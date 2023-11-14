# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'json'

class TenantAPI < CloudConfigTest

  SYSTEM_TENANTS = ["default"]
  
  def setup
    super
    set_owner("musum")
    set_description("Test the API to list, create and delete config tenants")
    @node = @vespa.nodeproxies.first[1]
    @hostname = @vespa.nodeproxies.first[0]
    @node.set_addr_configserver([@hostname])
  end
  
  def test_tenant_api
    @node.start_configserver

    tenants = list_tenants_assert(@hostname)
    assert_equal(SYSTEM_TENANTS, tenants["tenants"])
    get_tenant_assert("default")
    create_tenant_assert("foo")
    get_tenant_assert("foo")
    assert_equal(404, get_tenant("unknown", @hostname).code.to_i)
    tenants = list_tenants_assert(@hostname)
    assert_equal(create_excpected_tenants(["foo"]), tenants["tenants"])
    create_tenant_assert("bar")
    tenants = list_tenants_assert(@hostname)
    assert_equal(create_excpected_tenants(["foo", "bar"]), tenants["tenants"])
    delete_tenant_assert("foo")
    tenants = list_tenants_assert(@hostname)
    assert_equal(create_excpected_tenants(["bar"]), tenants["tenants"])
    delete_tenant_assert("bar")
    tenants = list_tenants_assert(@hostname)
    assert_equal(SYSTEM_TENANTS, tenants["tenants"])

    # Add a tenant that was previously deleted
    create_tenant_assert("foo")
    tenants = list_tenants_assert(@hostname)
    assert(tenants["tenants"]==["default","foo"])
    delete_tenant_assert("foo")
    assert(wait_for_tenants(@hostname, []))
    tenants = list_tenants_assert(@hostname)
    assert_equal(SYSTEM_TENANTS, tenants["tenants"])
      
    tenants = Array.new    
    # Many tenants:
    for i in 0..99
      tenants << "t#{i}"
      create_tenant("t#{i}", @hostname)
    end
    assert(wait_for_tenants(@hostname, tenants))
    for i in 0..99
      delete_tenant_assert("t#{i}")
    end
    assert(wait_for_tenants(@hostname, []))
    tenants = list_tenants_assert(@hostname)
    assert(SYSTEM_TENANTS, tenants["tenants"])
  end

  def create_tenant_assert(tenant)
    response = create_tenant_and_wait(tenant, @hostname)
    assert_equal(200, response.code.to_i)
  end

  def create_excpected_tenants(tenants)
    SYSTEM_TENANTS + tenants
  end

  def list_tenants_assert(hostname, port=DEFAULT_SERVER_HTTPPORT)
    response = list_tenants(hostname, port)
    assert_equal(200, response.code.to_i)
    get_json(response)
  end

  def delete_tenant_assert(tenant)
    response = delete_tenant(tenant, @hostname)
    assert_equal(200, response.code.to_i)
    get_json(response)
  end

  def get_tenant_assert(tenant)
    response = get_tenant(tenant, @hostname)
    assert_equal(200, response.code.to_i)
    get_json(response)
  end

  def teardown
    @node.stop_configserver
    stop
  end

end
