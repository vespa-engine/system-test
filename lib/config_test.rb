# Copyright Vespa.ai. All rights reserved.

require 'testcase'
require 'tenant_rest_api'
require 'app_generator/config_app'
require 'environment'

class ConfigTest < TestCase
  include TenantRestApi

  CONFIG_DEPLOY_APPS = CONFIG + "deploy/"
  CONFIG_VERIFIER = "#{Environment.instance.vespa_home}/bin/vespa-config-verification"
  ModelPlugin = Struct.new(:jarfile, :xmlfile)

  # Returns the modulename for this testcase superclass.
  # It is used by factory for categorizing tests.
  def modulename
    "config"
  end

  # Test app used in multiple config tests
  def app_with_logd(logserver_port)
    ConfigApp.new.admin(Admin.new.
                            config(ConfigOverride.new("cloud.config.log.logd").
                                add("logserver", ConfigValue.new("rpcport", logserver_port))))
  end

  def restart_config_server(node, args={})
    node.stop_configserver(args)
    node.start_configserver
    node.ping_configserver
  end

  def assert_response_code_and_body(resp, code=200, expected_body_elements=[])
    assert_response_code(resp, code)
    assert_response_body(resp, expected_body_elements)
  end

  def assert_response_code(resp, code=200)
    assert(resp)
    assert_equal(code, resp.code.to_i, resp.body)
  end

  def assert_response_body(resp, expected_body_elements=[])
    expected_body_elements.each do |expected_element|
      if (!(resp.body =~ /#{expected_element}/))
         assert(false, "'#{resp.body}' does not contain #{expected_element}")
      end
    end
  end

  def create_session_v2(hostname, tenant, application, expected_session_id, compression='gzip')
    if compression == 'gzip'
      compressed_data = `tar -C #{application} -czf - .`
      content_type = 'application/x-gzip'
    elsif compression == 'zip'
       compressed_data = `cd #{application} && zip -q -r - *`
       content_type = 'application/zip'
    else
      raise "Unknown compression type: #{compression}"
    end
    response = https_client.post(hostname, DEFAULT_SERVER_HTTPPORT, create_session_v2_path(tenant), compressed_data, query: 'verbose=true', headers: {'Content-Type' => content_type})
    json_response = JSON.parse(response.body)
    validate_create_session_response(json_response, hostname, tenant, expected_session_id)
    json_response
  end

  def create_session_v2_with_uri(hostname, tenant, from_url, expected_session_id)
    response = https_client.post(hostname, DEFAULT_SERVER_HTTPPORT, create_session_v2_path(tenant), nil, query: "verbose=true&from=#{from_url}")
    json_response = JSON.parse(response.body)
    validate_create_session_response(json_response, hostname, tenant, expected_session_id)
    json_response
  end

  private
  def create_session_v2_path(tenant)
    "/application/v2/tenant/#{tenant}/session"
  end

  private
  def validate_create_session_response(json_response, hostname, tenant, expected_session_id)
    assert_json_contains_field(json_response, "prepared")
    if expected_session_id > 0
      expected_prepare_url = "http://#{hostname}:#{DEFAULT_SERVER_HTTPPORT}#{create_session_v2_path(tenant)}/#{expected_session_id}/prepared"
      assert_equal(expected_prepare_url, json_response["prepared"])
    end
  end

  def prepare_session_v2(hostname, tenant, create_result, expected_session_id, port=DEFAULT_SERVER_HTTPPORT, timeout=nil, params={})
    prepare_session_internal(hostname, create_result, expected_session_id, port, timeout, tenant, params)
  end

  # TODO: Clean up code below to avoid code duplication
  def prepare_session_internal(hostname, create_result, expected_session_id, port=DEFAULT_SERVER_HTTPPORT, timeout=nil, tenant="default", params={})
    paramstring = create_param_string(params)
    uri = "#{create_result["prepared"]}?#{paramstring}"
    uri = uri + "&timeout=#{timeout}" if timeout

    response = put(uri)
    assert_response_code(response, 200)
    result = get_json(response)
    expected_activate_url = "http://#{hostname}:#{port}/application/v2/tenant/#{tenant}"
    expected_activate_url += "/session/#{expected_session_id}/active"
    assert_json_contains_field_value(result, "activate", expected_activate_url)
    result
  end

  def prepare_and_activate(hostname, tenant, create_result, expected_session_id, port=DEFAULT_SERVER_HTTPPORT, timeout=nil, params={})
    prepare_and_activate_internal(hostname, create_result, expected_session_id, port=DEFAULT_SERVER_HTTPPORT, timeout=nil, tenant, params={})
  end

  def prepare_and_activate_internal(hostname, create_result, expected_session_id, port=DEFAULT_SERVER_HTTPPORT, timeout=nil, tenant="default", params={})
    paramstring = create_param_string(params)
    uri = "#{create_result["prepared"].sub('prepared', 'prepareandactivate')}?#{paramstring}"
    uri = uri + "&timeout=#{timeout}" if timeout

    response = put(uri)
    assert_response_code(response, 200)
    result = get_json(response)
    result
  end

  def prepare_session_with_timeout(hostname, create_result, expected_session_id, timeout)
    prepare_session_internal(hostname, create_result, expected_session_id, DEFAULT_SERVER_HTTPPORT, timeout)
  end

  def prepare_session(create_result, response_code)
    response = put("#{create_result["prepared"]}?timeout=30.0")
    assert_response_code(response, response_code)
    get_json(response)
  end

  def activate_session(hostname, prepare_result, expected_session_id, timeout=20.0)
    response = put("#{prepare_result["activate"]}?timeout=#{timeout}")
    assert_response_code(response, 200)
    result = get_json(response)
    assert_json_field_value_matches(result, "message", Regexp.new("Session #{expected_session_id} activated\..*"))
    result
  end

  def activate_session_common(prepare_result, response_code)
    response = put(prepare_result["activate"])
    assert_response_code(response, response_code)
    get_json(response)
  end

  def activate_session_message_matches(hostname, prepare_result, response_code, regexp)
    result = activate_session_common(prepare_result, response_code)
    assert_json_field_value_matches(result, "message", regexp)
    result
  end

  def prepare_session_message(hostname, create_result, response_code, message)
    result = prepare_session(create_result, response_code)
    assert_json_contains_field_value(result, "message", message)
    result
  end        

  def prepare_session_message_matches(hostname, create_result, response_code, message)
    result = prepare_session(create_result, response_code)
    assert_json_field_value_matches(result, "message", message)
    result
  end

  def list_applications_v2(hostname, tenant, port=DEFAULT_SERVER_HTTPPORT)
    response = list_applications_v2_no_assert(hostname, tenant, port)
    assert_equal(200, response.code.to_i)
    get_json(response)
  end

  def list_applications_v2_no_assert(hostname, tenant, port=DEFAULT_SERVER_HTTPPORT)
    url="http://#{hostname}:#{port}/application/v2/tenant/#{tenant}/application/"
    http_request_get(URI(url), {})
  end

  def delete_application_v2(hostname, tenant, application_name, port=DEFAULT_SERVER_HTTPPORT)
    delete_application_v2_url("http://#{hostname}:#{port}/application/v2/tenant/#{tenant}/application/#{application_name}")
  end

  def delete_application_v2_url(url)
    response = http_request_delete(URI(url), {})
    assert_equal(200, response.code.to_i)
    get_json(response)
  end
  
  def assert_json_contains_field(json, field)
    assert(json.has_key?(field), "No field '#{field}' in response: #{JSON.dump(json)}")
  end

  def assert_json_contains_field_value(json, field, value)
    assert_json_contains_field(json, field)
    assert_equal(value, json[field])
  end

  def assert_json_field_value_matches(json, field, regexp)
    assert_json_contains_field(json, field)
    assert_match(regexp, json[field])
  end

  def put(url)
    http_request_put(URI(url), {})
  end

  def verify_configs(node, configservers, timeout=60)
    args = configservers.join(" ")
    endTime = Time.now + timeout
    success = false
    while Time.now < endTime do
      begin
        node.execute("#{CONFIG_VERIFIER} #{args}")
        success = true
      rescue
        sleep 1
      end
    end
    assert(success)
  end

  def activate_session_v2(hostname, tenant_name, application_name, environment, region, instance, prepare_result, expected_session_id, timeout=20.0)
    response = put("#{prepare_result["activate"]}?timeout=#{timeout}")
    assert_response_code(response, 200)
    result = get_json(response)
    assert_json_field_value_matches(result, "message", Regexp.new("Session #{expected_session_id} for tenant '#{tenant_name}' activated\..*"))
    assert_json_contains_field_value(result, "tenant", "#{tenant_name}")
    assert_json_contains_field_value(result, "url", "http://#{hostname}:19071/application/v2/tenant/#{tenant_name}/application/#{application_name}/environment/#{environment}/region/#{region}/instance/#{instance}")
    result
  end

  def get_config_v2_assert_200(hostname, tenant, application_name, instance_name, configName, configId, env_name="prod", region_name="default")
    url = "http://#{hostname}:19071/config/v2/tenant/#{tenant}/application/#{application_name}/environment/#{env_name}/region/#{region_name}/instance/#{instance_name}/#{configName}/#{configId}"
    response = http_request_get(URI(url), {})
    assert_equal(200, response.code.to_i)
    get_json(response)
  end

  def get_config_v2(hostname, tenant, application_name, instance_name, configName, configId, env_name="prod", region_name="default")
    url = "http://#{hostname}:19071/config/v2/tenant/#{tenant}/application/#{application_name}/environment/#{env_name}/region/#{region_name}/instance/#{instance_name}/#{configName}/#{configId}"
    response = http_request_get(URI(url), {})
    get_json(response)
  end

  def read_active_application_file(hostname, tenant_name, application_name, path)
    url = "#{application_url(hostname, tenant_name, application_name)}/content/#{path}"
    http_request_get(URI(url), {}) 
  end

  def application_url(hostname, tenant_name="default", app_name="default", environment="prod", region="default", instance="default")
    "#{https_client.scheme}://#{hostname}:19071/application/v2/tenant/#{tenant_name}/application/#{app_name}/environment/#{environment}/region/#{region}/instance/#{instance}"
  end

  def deploy_and_activate_session_v2(appdir, session_id, expected_port, application_name=@application_name, tenant_name=@tenant_name)
    result = create_session_v2(@hostname, tenant_name, appdir, session_id)
    result = prepare_session_v2(@hostname, tenant_name, result, session_id, DEFAULT_SERVER_HTTPPORT, nil, {"applicationName" => application_name})
    result = activate_session_v2(@hostname, tenant_name, application_name, @environment, @region, @instance, result, session_id)

    assert_logd_config_v2(expected_port, @hostname, tenant_name, application_name)
    next_session(session_id)
  end

  def assert_logd_config(portnum)
    config = get_config_v1("cloud.config.log.logd", "admin")
    assert(config.has_key?("logserver"));
    logserver = config["logserver"]
    assert(logserver.has_key?("rpcport"));
    assert_equal(portnum, logserver["rpcport"].to_i)
  end

  def assert_logd_config_v2(portnum, hostname, tenant_name, application_name, instance_name="default", env_name="prod", region_name="default")
    config = get_config_v2_assert_200(hostname, tenant_name, application_name, instance_name, "cloud.config.log.logd", "admin", env_name, region_name)
    assert(config.has_key?("logserver"));
    logserver = config["logserver"]
    assert(logserver.has_key?("rpcport"));
    assert_equal(portnum, logserver["rpcport"].to_i)
  end

  def delete_tenant_and_its_applications(hostname, tenant)
    response = list_tenants(hostname)
#    puts "response=#{response.body}"
    if (response.code.to_i == 200)
      tenants = JSON.parse(response.body)
#      puts "tenants=#{tenants}"
      if (tenants["tenants"])
        puts "Getting applications for tenant #{tenant}"
        response = list_applications_v2_no_assert(hostname, tenant)
        if (response.code.to_i == 200)
          applications = JSON.parse(response.body)
          applications.each do |app_url|
            puts "Deleting application #{app_url}"
            delete_application_v2_url(app_url)
          end
          delete_tenant(tenant, hostname)
        else
          puts "No applications for tenant #{tenant}"
        end
      end
    end
  end

  def next_session(session_id)
    return session_id + 1
  end

  def generate_app_with_hosts(name, host_alias_set, services, sdfile=nil)
    puts "name='#{name}'"
    # need a subdir so as to not overwrite when deploying
    path = dirs.tmpdir + "tmp/" + name
    puts "Creating path '#{path}'"
    `mkdir -p #{path}`
    File.open("#{path}/services.xml", "w") do |f|
      f.puts services
    end
    hosts = make_hosts_file(host_alias_set)
    File.open("#{path}/hosts.xml", "w") do |f|
      puts hosts
      f.puts hosts
    end
    if sdfile
      `mkdir -p #{path}/schemas`
      File.open("#{path}/schemas/music.sd", "w") do |f|
        File.open(sdfile, "r") do |r|
          line = r.readlines
          f.puts line
        end
      end
    end
    path
  end

  def make_hosts_file(host_aliases_to_use)
    s = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n" +
        "<hosts>\n"
    i = 1
    host_aliases_to_use.each do |host_alias|
      s += "<host name=\"foo#{i}\">\n" +
        "  <alias>#{host_alias}</alias>\n" +
        "</host>\n"
      i = i + 1
    end
    s += "</hosts>\n"
  end

  def save_configserver_app(configservernode)
    appdir = Environment.instance.vespa_home + "/conf/configserver-app/"
    svc = appdir + "services.xml"
    cmx = appdir + "config-models.xml"
    configservernode.execute("mv #{svc} #{svc}.orig && cp #{svc}.orig #{svc}")
    configservernode.execute("mv #{cmx} #{cmx}.orig && cp #{cmx}.orig #{cmx}")
  end

  def restore_configserver_app(configservernode)
    appdir = Environment.instance.vespa_home + "/conf/configserver-app/"
    svc = appdir + "services.xml"
    cmx = appdir + "config-models.xml"
    ccx = appdir + "configserver-config.xml"
    psc = appdir + "permanent-services.xml"
    configservernode.execute("mv #{svc}.orig #{svc}")
    configservernode.execute("mv #{cmx}.orig #{cmx}")
    configservernode.execute("rm -f #{ccx}")
    configservernode.execute("rm -f #{psc}")
  end

  def get_host_info(hostname, host)
    url = "http://#{hostname}:19071/application/v2/host/#{host}"
    http_request_get(URI(url), {})
  end

  def assert_deploy_app_fail(application)
    begin
      deploy_app(application)
    rescue ExecuteError => e
      return
    end
    assert(nil, "Expected deployment of #{application} to fail")
  end

  def assert_deploy_fail(application)
    begin
      deploy(application)
    rescue ExecuteError => e
      return
    end
    assert(nil, "Expected deployment of #{application} to fail")
  end

  def add_xml_file_to_configserver_app(configservernode, xml, filename)
    appdir = Environment.instance.vespa_home + "/conf/configserver-app/"
    configservernode.execute("echo '#{xml}' > #{appdir}/#{filename}")
    configservernode.execute("sed -i '/<container id/ a\
      <preprocess:include file=\"#{filename}\" required=\"false\"/>' #{appdir}/services.xml")
  end

  def remove_xml_file_from_configserver_app(configservernode, xml, filename)
    appdir = Environment.instance.vespa_home + "/conf/configserver-app/"
    configservernode.execute("rm -f #{appdir}/#{filename}")
    configservernode.execute("sed -i '/<preprocess:include file=\"#{filename}\"/d' #{appdir}/services.xml")
  end

  def create_param_string(params={})
    paramstring = ""
    params.each do |key, value|
      paramstring += "#{key}=#{value}&"
    end
    paramstring
  end

end
