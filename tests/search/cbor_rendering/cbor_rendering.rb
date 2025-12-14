# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class CborRendering < IndexedOnlySearchTest

  def setup
    set_owner("andreer")
    set_description("Test CBOR rendering support with format=cbor parameter")
  end

  def timeout_seconds
    300
  end

  def test_cbor_rendering
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")

    # Verify basic search works with JSON (default)
    assert_hitcount("query=sddocname:test", 3)
    assert_hitcount("query=title:CBOR", 1)

    # Get both JSON and CBOR responses for comparison
    qrserver = vespa.container.values.first
    query = "query=sddocname:test"

    # Get JSON response
    json_response = https_client.get(qrserver.name, qrserver.http_port, "/search/?#{query}")
    assert_equal(200, json_response.code.to_i, "JSON request should succeed")

    # Get CBOR response
    cbor_response = https_client.get(qrserver.name, qrserver.http_port, "/search/?#{query}&presentation.format=cbor")
    assert_equal(200, cbor_response.code.to_i, "CBOR request should succeed")
    assert(cbor_response.body.length > 0, "CBOR response should not be empty")

    # Verify CBOR is binary
    first_byte = cbor_response.body.bytes.first
    puts "CBOR first byte: 0x#{first_byte.to_s(16)}"
    assert_not_equal('{'.ord, first_byte, "Response should be CBOR binary, not JSON text")

    # Save responses to files for comparison
    json_file = "#{dirs.tmpdir}/response.json"
    cbor_file = "#{dirs.tmpdir}/response.cbor"

    File.write(json_file, json_response.body)
    File.binwrite(cbor_file, cbor_response.body)

    # Use Python to decode and compare
    comparison_script = selfdir + "compare_responses.py"
    result = `python3 #{comparison_script} #{json_file} #{cbor_file} 2>&1`
    puts result

    assert($?.success?, "JSON and CBOR responses should be identical after deserialization")
  end

end
