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
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    http
  end

  def with_https_connection(hostname, port, path, query=nil)
    uri = URI("#{scheme}://#{hostname}:#{port}#{path}")
    if query != nil
      uri.query = query
    end
    http = create_client(hostname, port)
    http.start { |conn|
      yield(conn, uri)
    }
  end

  def https_get(hostname, port, path, headers={})
    with_https_connection(hostname, port, path) do |conn, uri|
      conn.request(Net::HTTP::Get.new(uri, headers))
    end
  end

  private
  def ssl_ctx
    @tls_env.ssl_ctx
  end

  private
  def use_tls?
    ssl_ctx != nil
  end

  private
  def scheme
    use_tls? ? 'https' : 'http'
  end

end

