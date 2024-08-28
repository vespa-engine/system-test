require 'config_test'
require 'pp'

class ConfigRestApiV2 < CloudConfigTest
  @configserver = nil
  @csrvnode = nil
  @httpport = nil

  def setup
    super
    set_owner("musum")
    set_description("Tests config HTTP REST API v2")

    @node = @vespa.nodeproxies.first[1]

    deploy(selfdir+"app", nil, :force => true)
    start
    @csrvnode = vespa.configservers["0"]
    @configserver = vespa.configservers["0"].name
    @httpport = vespa.configservers["0"].ports[1]
    @urischeme = https_client.scheme # TODO Inline as 'https' once TLS is enforced
  end

  def base_url_long_appid
    "#{@urischeme}:\/\/#{@configserver}:#{@httpport}/config/v2/tenant/default/application/default/environment/prod/region/default/instance/default/"
  end

  def base_url_short_appid
    "http:\/\/#{@configserver}:#{@httpport}/config/v2/tenant/default/application/default/"
  end
  
  def verify_rest(base_url=base_url_long_appid())
    puts base_url
    
    sentinel_config_name = "cloud.config.sentinel"
    model_config_name = "cloud.config.model"
    threadpool_config_name = "container.handler.threadpool.container-threadpool"

    # Test get config
    resp = execute_http_request(base_url + model_config_name + "/admin/model")
    assert_response_code_and_body(resp, 200, ["configid\":\"hosts\/#{@configserver}\/configproxy"])

    # Test listing, non recursive (default). Includes first level of config id.
    resp = execute_http_request(base_url)
    assert_response_code_and_body(resp, 200, [sentinel_config_name,
                                              base_url + threadpool_config_name + "\/admin\/"])

    # Test listing, non recursive (explicit). Includes first level of config id.
    resp = execute_http_request(base_url + "?recursive=false")
    assert_response_code_and_body(resp, 200, [sentinel_config_name,
                                              base_url + threadpool_config_name + "\/admin\/"])

    # Test listing, recursive
    resp = execute_http_request(base_url + "?recursive=true")
    assert_response_code_and_body(resp, 200, [sentinel_config_name,
                                              base_url + threadpool_config_name + "\/admin\/cluster-controllers\/component\/threadpool@default-handler-common",
                                              base_url + threadpool_config_name + "\/admin\/metrics\/component\/threadpool@default-handler-common"])

    # Test named listing. Includes first level of config id.
    resp = execute_http_request(base_url + threadpool_config_name + "/")
    assert_response_code_and_body(resp, 200, [base_url + threadpool_config_name + "\/admin\/"])

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
  
  def test_rest_basic
    verify_rest
  end

  def test_rest_basic_short_appid
    verify_rest("#{@urischeme}:\/\/#{@configserver}:#{@httpport}/config/v2/tenant/default/application/default/")
  end

  def test_traverse_all_short_appid
    set_description("Recursively get everything and verify OK, short app id")
    traverse_configs(base_url_short_appid())
  end

  def test_traverse_all_long_appid
    set_description("Recursively get everything and verify OK, full app id")
    traverse_configs(base_url_long_appid())
  end
  
  def traverse_configs(url)
    resp = execute_http_request(url)
    resj = get_json(resp)
    assert_equal(200, resp.code.to_i, "Response: #{pp(resj)}")
    if resj.has_key?("children")
      traverse_listing(resj)
    else
      check_payload(resj, url)
    end            
  end
    
  def traverse_listing(resj)
    for child in resj["children"]
      traverse_configs(child)
    end  
    for config in resj["configs"]
      traverse_configs(config)
    end
  end

  def check_payload(resj, url)
    # Random samples of payload here, but not too many, too much to track
    if (url.end_with?("prelude.cluster.qr-monitor/container"))
      assert_equal(5000, resj["requesttimeout"])
    end
    if (url.end_with?("container.jdisc.jdisc-bindings/container"))
      assert_equal("http://*/search/*", resj["handlers"]["com.yahoo.search.handler.SearchHandler"]["serverBindings"][0])
    end
  end
    
  def execute_http_request(url)
    http_request(URI(url), {})
  end

  def teardown
    stop
  end
end
