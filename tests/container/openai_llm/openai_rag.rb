require 'search_container_test'


class GenerateOpenAI < SearchContainerTest
  def setup
    @valgrind = false
    set_owner('glebashnik')
    set_description('Test feeding generator with OpenAI API')
  end

  def timeout_seconds
    600
  end
  
  # This test is disabled because it requires either an API-key or a mock OpenAI-compatible server.
  def no_test_openai_rag
    add_bundle(selfdir + 'LocalSecrets.java')
    deploy(selfdir + 'app')
    start
    feed(:file => selfdir + "data/one.jsonl")
    wait_for_hitcount('query=manhattan', 1)
    prompt = "What was the Manhattan project?"
    assert_json_response(prompt)
    assert_sse_response(prompt)
  end

  def assert_json_response(prompt)
    query = {
      'searchChain' => 'openai',
      'query' => prompt,
      'format' => 'json',
    }
    result = search(query)
    puts "Result is: #{result}"
    parsed_data = JSON.parse(result)
  
    # Assert that the root object exists with id "token_stream"
    assert_equal(true, parsed_data.has_key?("root"), "Response missing root element")
    assert_equal("token_stream", parsed_data["root"]["id"], "Root id is not token_stream")
    
    # Assert that we have event_stream in children
    event_stream = parsed_data["root"]["children"].find { |child| child["id"] == "event_stream" }
    assert_not_nil(event_stream, "Missing event_stream in children")
    
    # Assert minimum number of tokens (children of event_stream)
    token_children = event_stream["children"]
    assert_not_nil(token_children, "Missing children in event_stream")
    assert(token_children.length >= 10, "Expected at least 10 tokens, but got #{token_children.length}")
    
    # Verify token format for a few tokens
    tokens_with_text = token_children.select { |t| t["fields"] && t["fields"]["token"] }
    assert(tokens_with_text.length > 0, "No tokens with text found")
end

  def assert_sse_response(prompt)
    query = {
      'searchChain' => 'openai',
      'query' => prompt,
      'format' => 'sse',
      'traceLevel' => '1',
    }
    result = search(query)
    puts "Result is: #{result}"
  
    # Check for prompt event
    assert_equal(true, result.include?("event: prompt"), "Missing prompt event")
    assert_equal(true, result.include?("data: {\"prompt\":"), "Missing prompt data")
    
    # Check for token events
    token_events = result.scan(/event: token/)
    assert(token_events.length >= 10, "Expected at least 10 token events, got #{token_events.length}")
    
    # Check token data format
    token_data_matches = result.scan(/data: \{"token":"[^"]*"\}/)
    assert(token_data_matches.length >= 10, "Expected at least 10 token data entries, got #{token_data_matches.length}")

    # Check proper SSE format (events followed by data)
    assert_equal(true, result.include?("event: token\ndata: {\"token\":"), "Incorrect SSE format")
  end

  def search(query)
    query = "/search/?" + URI.encode_www_form(query.to_a)
    puts "Query is: #{query}"
    container = vespa.container.values.first
    result = container.http_get("localhost", Environment.instance.vespa_web_service_port, query, nil, {})
    assert_equal(200, result.code.to_i)
    result.body
  end


end
