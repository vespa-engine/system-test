# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'json'
require 'net/http'
require 'uri'

class McpServerTest < SearchContainerTest

  def setup
    set_description("Check that application with MCP components can be created and handle requests")
    set_owner("edvardwd")
    @valgrind = false

    add_bundle_dir(selfdir + "bundle", "app")
    deploy(selfdir + "app")
    start
    @container = vespa.container.values.first
  end

  def test_all
    # Run all tests in sequence
    print_test_header("INITIALIZE REQUEST")
    initalize_request_test()

    print_test_header("LIST TOOLS")
    list_tools_test()
    
    print_test_header("GET SCHEMAS")
    get_schemas_test()
    
    print_test_header("EXECUTE QUERY")
    execute_query_test()
    
    print_test_header("GET DOCUMENTATION")
    get_documentation_test()
  end

  def initalize_request_test
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
    
    parsed_response = JSON.parse(response)
    assert_equal("2.0", parsed_response["jsonrpc"])
    assert_equal(1, parsed_response["id"])
  end

  def list_tools_test
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
  
  
  def get_schemas_test
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
    assert(parsed_response["result"]["content"].is_a?(Array))
    assert(parsed_response["result"]["content"][0]["text"].include?("person"))
  end
  
  def execute_query_test
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
    # Checks if the execute query tool call doesn't return an error
    response = send_jsonrpc_request(jsonrpc_request)
    
    assert_not_nil(response)
    parsed_response = JSON.parse(response)
    assert_equal(false, parsed_response["result"]["isError"])
    assert(parsed_response["result"].key?("content"))
    assert(parsed_response["result"]["content"].is_a?(Array))
    parsed_content = JSON.parse(parsed_response["result"]["content"][0]["text"])

    # Check that root exists and children is empty (no documents fed yet)
    assert(parsed_content.key?("root"))
    assert_equal(0, parsed_content["root"]["fields"]["totalCount"])

    # Feed document and re-run the query to check if we get results
    feed_and_wait_for_docs("person", 1, :file => "#{selfdir}/docs.json", :maxpending => 1)
    jsonrpc_request["id"] = 5

    response = send_jsonrpc_request(jsonrpc_request)
    assert_not_nil(response)
    parsed_response = JSON.parse(response)
    assert_equal(false, parsed_response["result"]["isError"]) 
    assert(parsed_response["result"].key?("content"))
    assert(parsed_response["result"]["content"].is_a?(Array))
    assert_not_nil(parsed_response["result"]["content"][0]["text"].include?("John Doe"))
  end

  def get_documentation_test
    jsonrpc_request = {
      "jsonrpc" => "2.0",
      "id" => 6,
      "method" => "tools/call",
      "params" => {
        "name" => "getDocumentation",
        "arguments" => {
          "userinput" => "Vespa CLI"
        }
      }
    }
    # Checks if the get documentation tool call returns some content
    response = send_jsonrpc_request(jsonrpc_request)
    assert_not_nil(response)
    parsed_response = JSON.parse(response)
    assert_equal(false, parsed_response["result"]["isError"])
    assert(parsed_response["result"].key?("content"))
    assert(parsed_response["result"]["content"].is_a?(Array))
    assert_not_nil(parsed_response["result"]["content"][0]["text"])
  end

  def send_jsonrpc_request(request_body)
        # Helper function to send a JSON-RPC request to the MCP endpoint
        header = {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
        response = vespa.container.values.first.http_get("localhost", 0, "/mcp/", request_body.to_json, header)

        response.body
  end

  def print_test_header(test_name)
    width = 60
    text = "Running the following test: " + test_name
    puts "#" * width
    puts "# " +  text.center(width - 4) + " #"
    puts "#" * width
    print "\n"
  end

  def teardown
    stop
  end

end