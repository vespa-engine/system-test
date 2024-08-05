# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'environment'

class HttpFilterTest < SearchContainerTest
  def setup
    set_owner("gjoranv")
    set_description("Tests that http server and filters can be configured with 'filtering' xml syntax.")
    add_bundle_dir(File.expand_path(selfdir), "test-bundle")
    deploy(selfdir+"app")
    start

    @container = @vespa.container.values.first
  end

  def test_http_filter
    check_response_filter_chain
    check_request_filter_chain
    check_request_response_filters
    check_default_request_response_filters
    check_strict_mode
  end

  def check_response_filter_chain
    filter_names = ["TestSecurityResponseFilter", "TestResponseFilter"]

    response = http_get_test_handler(4080)
    filter_names.each { |name|
      assert_response_filtered(response, name)
    }
  end

  def check_request_filter_chain
    response = http_get_test_handler(4082)
    assert_equal("Forbidden by TestSecurityRequestFilter", response.body)
    assert_kind_of(response, Net::HTTPForbidden)
  end

  def check_request_response_filters
    response = http_get_test_handler(4083)
    assert_response_filtered(response, "TestResponseFilter")
    assert_equal("TestFilterHandler: TestRequestFilter", response.body)
  end

  def check_default_request_response_filters
    response = http_get_test_handler(4084)
    assert_response_filtered(response, "TestResponseFilter")
    assert_equal("TestFilterHandler: TestRequestFilter", response.body)
  end

 def check_strict_mode
   response = http_get_test_handler(4085)
   assert_equal("Request did not match any request filter chain", response.body)
 end

  def http_get_test_handler(port)
    @container.http_get("localhost", port, "/TestHandler")
  end

  def http_get_application_status(port)
    @container.http_get("localhost", port, "/ApplicationStatus")
  end


  def assert_response_filtered(response, filter_name)
    assert_equal("true", response["X-#{filter_name}"],
                 "#{filter_name} not run.")
  end

  def assert_kind_of(obj, klass)
    assert(obj.kind_of?(klass), "Expected #{klass}, got #{obj.class}")
  end

  def teardown
    stop
  end
end
