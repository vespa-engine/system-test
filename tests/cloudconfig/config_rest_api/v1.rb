require 'cloudconfig_test'

class ConfigRestApiV1 < CloudConfigTest
  @configserver = nil
  @csrvnode = nil
  @httpport = nil
   
  def setup
    super
    set_owner("musum")
    set_description("Tests config HTTP REST API")

    @node = @vespa.nodeproxies.first[1]

    deploy(selfdir+"app", nil, :force => true)
    start
    @csrvnode = vespa.configservers["0"]
    @configserver = vespa.configservers["0"].name
    @httpport = vespa.configservers["0"].ports[1]
    @urischeme = https_client.scheme # TODO Inline as 'https' once TLS is enforced
  end

  def base_url
    path = "/config/v1/"
    return "#{@urischeme}:\/\/#{@configserver}:#{@httpport}#{path}"
  end

  def test_rest_basic
    puts base_url
    
    sentinel_config_name = "cloud.config.sentinel"
    model_config_name = "cloud.config.model"
    filedistributorrpc_config_name = "cloud.config.filedistribution.filedistributorrpc"
    
    # Test listing, non recursive (default). Includes first level of config id.
    resp = execute_http_request(base_url)
    assert_response_code_and_body(resp, 200, [sentinel_config_name,
                                              base_url + filedistributorrpc_config_name + "\/filedistribution\/"])

    # Test listing, non recursive (explicit). Includes first level of config id.
    resp = execute_http_request(base_url + "?recursive=false")
    assert_response_code_and_body(resp, 200, [sentinel_config_name,
                                              base_url + filedistributorrpc_config_name + "\/filedistribution\/"])

    # Test listing, recursive
    resp = execute_http_request(base_url + "?recursive=true")
    assert_response_code_and_body(resp, 200, [sentinel_config_name,
                                              base_url + filedistributorrpc_config_name + "\/filedistribution\/",
                                              base_url + filedistributorrpc_config_name + "\/filedistribution\/#{@configserver}"])

    # Test named listing. Includes first level of config id.
    resp = execute_http_request(base_url + filedistributorrpc_config_name + "/")
    assert_response_code_and_body(resp, 200, [base_url + filedistributorrpc_config_name + "\/filedistribution\/"])

    # Test get config
    resp = execute_http_request(base_url + model_config_name + "/admin/model")
    assert_response_code_and_body(resp, 200, ["configid\":\"hosts\/#{@configserver}\/configproxy"])

    # Test get config with nocache property set
    resp = execute_http_request(base_url + model_config_name + "/admin/model?nocache=true")
    assert_response_code_and_body(resp, 200, ["configid\":\"hosts\/#{@configserver}\/configproxy"])

    # Test get config with invalid config name
    resp = execute_http_request(base_url + model_config_name + "/nonexisting")
    assert_response_code_and_body(resp, 404)

    # Test get config with invalid config id
    resp = execute_http_request(base_url + model_config_name + "/nonexisting")
    assert_response_code_and_body(resp, 404)
  end

  def execute_http_request(url)
    http_request(URI(url), {})
  end

  def teardown
    stop
  end
end
