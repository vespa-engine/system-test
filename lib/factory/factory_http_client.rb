# Copyright Vespa.ai. All rights reserved.

require 'timeout'
require 'json'
require 'zlib'
require 'factory_authentication'

class FactoryHttpClient

  def initialize(log = nil)
    @user_agent = "Vespa Factory Client (ruby #{RUBY_VERSION})"
    @auth = FactoryAuthentication.new
    @log = log
  end

  ALL_NET_HTTP_ERRORS = [
    Timeout::Error,  EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, Net::HTTPError,
    Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Errno::EPIPE, Errno::EINVAL, Errno::ECONNRESET,
    Errno::EHOSTUNREACH
  ]

  def request(path, method='GET', body=nil, headers=nil)
    uri = URI(@auth.factory_api + path)
    @log&.info("Making #{method} request to #{uri}")
    @log&.debug("Request body: #{body}") if body

    case method
    when 'DELETE'
      request = Net::HTTP::Delete.new(uri)
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'PATCH'
      request = Net::HTTP::Patch.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
    when 'PUT'
      request = Net::HTTP::Put.new(uri)
    else
      raise "Unsupported request method #{method}"
    end

    if body
      gzip = Zlib::GzipWriter.new(StringIO.new)
      gzip << body
      request.body = gzip.close.string

      request.add_field('Content-Encoding', 'gzip')
      request.add_field('Content-Type', "application/json") unless headers
    end

    headers.each { |k,v| request.add_field(k, v) } if headers

    request.add_field('User-Agent', @user_agent)
    request.add_field('Authorization', "Bearer #{@auth.token}")

    http = @auth.client

    begin
      retries ||= 0
      sleep retries
      response = http.request(request)

      # This method will throw an Net::HTTPError if the response is not 2xx (this is a badly named method)
      response.value
      @log&.info("HTTP request completed successfully: #{response.code} #{response.message}")

    rescue *ALL_NET_HTTP_ERRORS => e
      @log&.warn("HTTP request failed (attempt #{retries + 1}/5): #{e.message}")
      retry if (retries += 1) < 5
      @log&.error("HTTP request failed after #{retries} retries: #{e.message}")
      raise "Could not execute http request after #{retries} retries. Exception: #{e.message}"
    end

    response
  end
end
