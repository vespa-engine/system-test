# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'app_generator/container_app'
require 'json'
require 'net/http'
require 'uri'

class McpServerTest < SearchContainerTest

  def setup
    set_description("Check that application with MCP components can be created and handle requests")
    @valgrind = false
    @container_port = Environment.instance.vespa_web_service_port
    
    deploy_application()
    start
    @container = vespa.container.values.first
  end

  def test_initalize_request
    # Simple JSON-RPC request to test MCP endpoint
    jsonrpc_request = {
      "jsonrpc" => "2.0",
      "method" => "initialize",
      "params" => {
        "protocolVersion" => "2025-06-18",
        "capabilities" => {},
        "clientInfo" => {
            "name" => "test-client",
            "version" => "1.0.0",
        }
      },
      "id" => 1
    }
    
    response = send_jsonrpc_request(jsonrpc_request)
    assert_not_nil(response)
    
    # Parse response and verify it's valid JSON-RPC
    parsed_response = JSON.parse(response)
    assert_equal("2.0", parsed_response["jsonrpc"])
    assert_equal(1, parsed_response["id"])
  end

  def test_list_tools
    jsonrpc_request = {
        "jsonrpc" => "2.0",
        "id" => "2",
        "method" => "tools/list",
        "params" => {}
    }
    # Checks if the MCP server lists the "getDocumentation" tool
    response = send_jsonrpc_request(jsonrpc_request)
    assert_not_nil(response)
    parsed_response = JSON.parse(response)
    assert(parsed_response["result"].key?("tools"))
    assert(parsed_response["result"]["tools"].any? { |tool| tool["name"] == "getDocumentation" })

  end


  def test_get_schemas
    jsonrpc_request = {
      "jsonrpc" => "2.0",
      "id" => 3,
      "method" => "tools/call",
      "params" => {
        "name" => "getSchemas",
        "arguments" => {}
      }
    }
    # Checks if the MCP server finds the "person" schema
    response = send_jsonrpc_request(jsonrpc_request)
    assert_not_nil(response)
    parsed_response = JSON.parse(response)
    assert(parsed_response["result"].key?("content"))
    assert(parsed_response["result"]["content"].key?("text"))
    assert(parsed_response["result"]["content"]["text"].include?("person"))
  end

  def test_simple_query
    jsonrpc_request = {
      "jsonrpc" => "2.0",
      "id" => 4,
      "method" => "tools/call",
      "params" => {
        "name" => "executeQuery",
        "arguments" => {
          "parameters" => {
            "sources" => "person"
          },
          "yql" => "select * from sources where true"
        }
      }
    }

    response = send_jsonrpc_request(jsonrpc_request)
    assert_not_nil(response)
    parsed_response = JSON.parse(response)
    assert_equal(false, parsed_response["result"]["isError"])
  end

  def send_jsonrpc_request(request_body)
        # Helper function to send a JSON-RPC request to the MCP endpoint
        uri = URI("http://localhost:#{@container_port}/mcp/")
        http = Net::HTTP.new(uri.host, uri.port)
        
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = request_body.to_json
        
        response = http.request(request)
        response.body
  end

  def teardown
    stop
  end

end