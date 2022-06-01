# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rest_api'
require 'test_base'

# Note: WIP, no real support for API yet, just a start
module ApplicationV2Api
  include RestApi
  include TenantRestApi

  DEFAULT_SERVER_HTTPPORT = 19071

  def deploy_app_v2_api(app_dir, hostname=@configserver.hostname, tenant_name=@tenant_name, application_name=@application_name)
    create_tenant_and_wait(tenant_name, hostname)

    app = create_application_package(app_dir, hostname)
    session_url = URI("http://#{hostname}:#{DEFAULT_SERVER_HTTPPORT}/application/v2/tenant/#{tenant_name}/session")
    uploaded_response = http_request_post(session_url, { :body => File.read(app), :headers => {"Content-Type" => "application/x-gzip"}})
    verify_ok_response(uploaded_response)
    uploaded_response_map = JSON.parse(uploaded_response.body)

    prepared_url = uploaded_response_map["prepared"]
    prepared_response = http_request_put(URI(prepared_url << "?applicationName=#{application_name}"))
    prepared_map = JSON.parse(prepared_response.body)
    verify_ok_response(uploaded_response)

    activate_url = prepared_map["activate"]
    http_request_put(URI(activate_url))
  end

  def create_prepare_and_activate(app_dir, hostname=@configserver.hostname, tenant_name=@tenant_name, application_name=@application_name)
    create_tenant_and_wait(tenant_name, hostname)

    app = create_application_package(app_dir, hostname)
    url = URI("http://#{hostname}:#{DEFAULT_SERVER_HTTPPORT}/application/v2/tenant/#{tenant_name}/prepareandactivate")
    response = http_request_post(url, { :body => File.read(app), :headers => {"Content-Type" => "application/x-gzip"}})
    verify_ok_response(response)
  end

  def create_application_package(app_dir, hostname)
    tmpdir = Dir.mktmpdir("app", dirs.tmpdir) # To make sure concurrent calls do not use the same tmp dir
    tmpdest = tmpdir + File.basename(app_dir) + ".tgz"
    cmd = "tar -C #{app_dir} -czf #{tmpdest} . 2>&1"
    puts "Executing: #{cmd}"
    puts `#{cmd}`
    tmpdest
  end

  def verify_ok_response(response)
    raise response.body if response.code.to_i != 200
  end

end
