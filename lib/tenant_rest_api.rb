# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rest_api'
require 'test_base'

module TenantRestApi
  include RestApi

  DEFAULT_SERVER_HTTPPORT = 19071

  def list_tenants(hostname, port=DEFAULT_SERVER_HTTPPORT)
    url="http://#{hostname}:#{port}/application/v2/tenant/"
    http_request_get(URI(url), {})
  end

  # Note: Unless you know what you are doing, use create_tenant_and_wait[s]
  def create_tenant(tenant, hostname, port=DEFAULT_SERVER_HTTPPORT)
    url="http://#{hostname}:#{port}/application/v2/tenant/#{tenant}"
    http_request_put(URI(url), {})
  end

  def get_tenant(tenant, hostname, port=DEFAULT_SERVER_HTTPPORT)
    url="http://#{hostname}:#{port}/application/v2/tenant/#{tenant}"
    http_request_get(URI(url), {})
  end

  def create_tenant_and_wait(tenant, hostname, port=DEFAULT_SERVER_HTTPPORT)
    response = create_tenant(tenant, hostname, port)
    wait_for_tenants(hostname, [tenant])
    response
  end

  def create_tenants_and_wait(tenants, hostname, port=DEFAULT_SERVER_HTTPPORT)
    tenants.each do |tenant|
      create_tenant(tenant, hostname, port)
    end
    wait_for_tenants(hostname, tenants)
  end

  def wait_for_tenants(hostname, tenants, port=DEFAULT_SERVER_HTTPPORT)
    found_all = false
    for i in 1..2000 do
      found_all = has_tenants?(hostname, tenants, port)
      if found_all
        break
      end
      sleep 0.1
    end
    found_all
  end

  def has_tenants?(hostname, tenants, port=DEFAULT_SERVER_HTTPPORT)
    response = get_json(list_tenants(hostname, port))
    return false unless response
    num_found = 0
    json = response["tenants"]
    unless json
      puts "Could not find any tenants in response: #{response}"
      return false
    end
    tenants.each do |t|
      if json.include?(t)
        num_found += 1
      end
    end
    return (num_found == tenants.size)
  end

  def delete_tenant_application(tenant, application, hostname, port=DEFAULT_SERVER_HTTPPORT)
    url="http://#{hostname}:#{port}/application/v2/tenant/#{tenant}/application/#{application}"
    http_request_delete(URI(url), {})
  end

  def delete_tenant(tenant, hostname, port=DEFAULT_SERVER_HTTPPORT)
    url="http://#{hostname}:#{port}/application/v2/tenant/#{tenant}"
    result = http_request_delete(URI(url), {})
    if result.code.to_i == 200
      wait_for_tenants_removed(hostname, [tenant], port)
    end
    result
  end

  def wait_for_tenants_removed(hostname, tenants, port=DEFAULT_SERVER_HTTPPORT)
    found_none = false
    for i in 1..1000 do
      found_none = !has_tenants?(hostname, tenants, port)
      if found_none
        break
      end
      sleep 0.1
    end
    found_none
  end

end
