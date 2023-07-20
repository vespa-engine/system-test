# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'tls_env'
require 'net/http'
require 'uri'
require 'json'

# Creates a Net::HTTP client based on TlsEnv

class HttpsClient

  def initialize(tls_env)
    @tls_env = tls_env
  end

  def create_client(host, port)
    http = Net::HTTP.new(host, port)
    if use_tls?
      http.use_ssl = true
      http.cert_store = ssl_ctx.cert_store
      http.cert = ssl_ctx.cert
      http.key = ssl_ctx.key
      http.verify_mode = ssl_ctx.verify_mode
      http.ssl_version = :TLSv1_2 # TODO allow TLSv1.3 once https://bugs.ruby-lang.org/issues/19017 is resolved
    end
    http
  end

  def with_https_connection(hostname, port, path, query: nil)
    uri = URI("#{scheme}://#{hostname}:#{port}#{path}")
    if query != nil
      uri.query = query
    end
    http = create_client(hostname, port)
    http.start { |conn|
      yield(conn, uri)
    }
  end

  def get(hostname, port, path, headers: {}, query: nil)
    with_https_connection(hostname, port, path, query: query) do |conn, uri|
      conn.request(Net::HTTP::Get.new(uri, headers))
    end
  end

  def post(hostname, port, path, body, headers: {}, query: nil)
    with_https_connection(hostname, port, path, query: query) do |conn, uri|
      request = Net::HTTP::Post.new(uri, headers)
      request.body = body
      conn.request(request)
    end
  end

  def delete(hostname, port, path, headers: {}, query: nil)
    with_https_connection(hostname, port, path, query: query) do |conn, uri|
      conn.request(Net::HTTP::Delete.new(uri, headers))
    end
  end

  def put(hostname, port, path, body, headers: {}, query: nil)
    with_https_connection(hostname, port, path, query: query) do |conn, uri|
      request = Net::HTTP::Put.new(uri, headers)
      request.body = body
      conn.request(request)
    end
  end

  # TODO Inline as 'https' once TLS is enforced.
  def scheme
    use_tls? ? 'https' : 'http'
  end

  def verify_success(response)
    raise StandardError.new("Expected 2xx, got response code #{response.code}") unless response.is_a?(Net::HTTPSuccess)
  end

  private
  def ssl_ctx
    @tls_env.ssl_ctx
  end

  private
  def use_tls?
    ssl_ctx != nil
  end

end

