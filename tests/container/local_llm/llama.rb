# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class LLMInContainerTest < SearchContainerTest

  def setup
    @valgrind = false
    set_owner("lesters")
    set_description("Verify that local LLMs can be evaluated in container.")
  end

  def timeout_seconds
    return 600
  end

  def test_local_llm_in_container
    deploy(selfdir + "app")
    start
    prompt = "What was the Manhattan project?"
    assert_json_response(prompt)
    assert_sse_response(prompt)
  end

  def assert_json_response(prompt)
    query = {
      'searchChain' => 'llm',
      'query' => prompt,
      'format' => 'json',
    }
    result = search(query)

    parsed_data = JSON.parse(result)
    assert_equal(true, parsed_data.has_key?("root"))
    assert_equal(true, parsed_data["root"]["children"][0]["children"].length > 0)
  end

  def assert_sse_response(prompt)
    query = {
      'searchChain' => 'llm',
      'query' => prompt,
      'format' => 'sse',
      'traceLevel' => '1',
    }
    result = search(query)
    tokens = extract_tokens(result)
    assert_equal(11, tokens.length, "Did not contain correct number of generated tokens")
    assert_equal(true, result.include?("data: {\"prompt\":\"#{prompt}\"}"), "Did not contain prompt")
    assert_equal(true, result.include?("Generated tokens: 11"), "Did not display correct number of generated tokens")
  end

  def teardown
    stop
  end

  def search(query)
    query = "/search/?" + URI.encode_www_form(query.to_a)
    puts "Query is: #{query}"
    container = vespa.container.values.first
    result = container.http_get("localhost", 8080, query, nil, {})
    assert_equal(200, result.code.to_i)
    return result.body
  end

  def extract_tokens(event_stream)
    tokens = []
    event_stream.split("\n\n").each do |block|
      lines = block.split("\n")
      if lines[0] == "event: token"
        token_data = lines[1].match(/"token":"([^"]*)"/)
        tokens << token_data[1] if token_data
      end
    end
    return tokens
  end



end
