# Copyright Vespa.ai. All rights reserved.

require 'assertions'
require 'erb'
require 'set'
require 'http_connection_pool'

class HttpResponseError < RuntimeError
  attr_reader :response_code, :response_message
  def initialize(msg, response_code, response_message)
    super(msg)
    @response_code = response_code
    @response_message = response_message
  end
end

class JsonLinesResponseHandler
  def on_put(doc_id, fields)
  end

  def on_remove(doc_id)
  end

  def on_continuation(token, percent_finished)
  end

  def on_document_count(doc_count)
  end
end

# Class to use the document rest api (v1) for feed, get, visit (https://docs.vespa.ai/documentation/document-api.html)
class DocumentApiV1
  include Assertions

  attr_reader :host, :port

  @@known_request_params = [:concurrency, :condition, :create, :cluster, :continuation, 'format.tensors', :format,
                            :fieldSet, :route, :selection, :wantedDocumentCount, :bucketSpace, :stream].to_set

  def initialize(host, port, test_case)
    @host = host
    @port = port
    @test_case = test_case
    @connectionPool = HttpConnectionPool.new(test_case.tls_env)
  end

  def request_params(params={})
    key_value_params = params.select{ |k, v| @@known_request_params.include?(k) }.
      map{ |k, v| "#{k}=#{uri_enc(v.to_s)}" }.
      join('&')
    if key_value_params.empty?
      ""
    else
      "?" + key_value_params
    end
  end

  def get_connection(params={})
    if params[:port]
      port = params[:port]
    else
      port = @port
    end
    @connectionPool.acquire(@host, port)
  end

  def http_post(path, content, params={}, headers={})
    unless params[:brief]
      @test_case.output("http_post('#{path}', '#{content}'")
    end
    connection = get_connection(params)
    response = connection.getConnection.post(path, content, headers.merge({ 'Content-Type' => 'application/json'}))
    @connectionPool.release(connection)
    assert_response_ok(response)
    response.body
  end

  def http_put(path, content, params={}, headers={})
    unless params[:brief]
      @test_case.output("http_put('#{path}', '#{content}'")
    end
    connection = get_connection(params)
    response = connection.getConnection.put(path, content, headers.merge({ 'Content-Type' => 'application/json'}))
    @connectionPool.release(connection)
    assert_response_ok(response)
    response.body
  end

  def http_get(path, params={}, headers={})
    unless params[:brief]
      @test_case.output("http_get('#{path}')")
    end
    connection = get_connection(params)
    response = connection.getConnection.get(path, headers)
    @connectionPool.release(connection)
    response
  end

  def http_delete(path, params={})
    unless params[:brief]
      @test_case.output("http_delete('#{path}')")
    end
    connection = get_connection(params)
    response = connection.getConnection.delete(path)
    @connectionPool.release(connection)
    assert_response_ok(response)
    response.body
  end

  def assert_response_ok(response)
    if response.code.to_i != 200
      raise HttpResponseError.new("Expected HTTP 200 OK, got HTTP #{response.code} with body '#{response.body}'",
                                  response.code.to_i, response.body)
    end
  end

  def parse_doc_id(doc_id)
    if doc_id !~ /id:([^:]*):([^:]+):([gn]=[^:]+)?:(.*)/
      raise "Could not parse document ID: '#{doc_id}'"
    end
    { :namespace => $~[1], :doc_type => $~[2], :group_spec => $~[3], :rest => $~[4]}
  end

  def uri_enc(str)
    ERB::Util.url_encode(str)
  end

  def doc_id_to_v1_uri(doc_id)
    parsed_id = parse_doc_id(doc_id)
    location = 'docid'
    if not (parsed_id[:group_spec].nil? or parsed_id[:group_spec].empty?)
      fragments = parsed_id[:group_spec].split('=')
      location = "#{fragments[0] == 'n' ? 'number' : 'group'}/#{uri_enc(fragments[1])}"
    end
    "/document/v1/#{uri_enc(parsed_id[:namespace])}/#{uri_enc(parsed_id[:doc_type])}/#{location}/#{uri_enc(parsed_id[:rest])}"
  end

  def do_mutating_op(document, params={})
    uri = doc_id_to_v1_uri(document.documentid)
    uri += request_params(params)
    yield(uri, document.fields_to_json, params)
  end

  def put(document, params={})
    do_mutating_op(document, params) { |uri, json, params|
      http_post(uri, json, params)
    }
  end

  def update(update, params={})
    do_mutating_op(update, params) { |uri, json, params|
      http_put(uri, json, params)
    }
  end

  def get(doc_id, params={})
    uri = doc_id_to_v1_uri(doc_id) + request_params(params)
    response = http_get(uri, params)
    if response.code.to_i == 200
      json = JSON.parse(response.body)
      Document.create_from_json(json)
    elsif response.code.to_i == 404
      return nil
    else
      raise "Expected HTTP 200 OK or HTTP 404, got HTTP #{response.code} with body '#{response.body}'"
    end
  end

  def remove(doc_id, params={})
    uri = doc_id_to_v1_uri(doc_id) + request_params(params)
    http_delete(uri, params)
  end

  def visit(params={})
    uri = "/document/v1/" + request_params(params)
    response = http_get(uri, params)
    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      raise "Expected HTTP 200 OK, got HTTP #{response.code} with body '#{response.body}'"
    end
  end

  def visit_jsonl_stream(response_handler, params={})
    uri = "/document/v1/" + request_params(params.merge({:stream => true}))
    # Prefer JSONL but also accept JSON (though we only _expect_ JSONL here)
    headers = {'Accept' => 'application/jsonl, application/json;q=0.9'}
    response = http_get(uri, params, headers)
    unless response.code.to_i == 200
      raise "Expected HTTP 200 OK, got HTTP #{response.code} with body '#{response.body}'"
    end
    # Ideally we'd use a streaming response reader here, but the Ruby HTTP library doc
    # implies that when a block is passed, it will receive whatever's read from the
    # socket (i.e. transport level), _not_ something that's on an HTTP-level chunked
    # response boundary (i.e. protocol level). So in the interest of simplicity and not
    # having to do our own line buffering, just read everything in one go.
    response.body.each_line do |line|
      jl = JSON.parse(line)
      if jl.has_key? 'put'
        response_handler.on_put(jl['put'], jl['fields'])
      elsif jl.has_key? 'remove'
        response_handler.on_remove jl['remove']
      elsif jl.has_key? 'continuation'
        cont = jl['continuation']
        maybe_token = cont.has_key?('token') ? cont['token'] : nil
        response_handler.on_continuation(maybe_token, cont['percentFinished'])
      elsif jl.has_key? 'sessionStats'
        response_handler.on_session_stats jl['sessionStats']
      end
    end
  end

end

