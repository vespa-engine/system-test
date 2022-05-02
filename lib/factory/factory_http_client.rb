# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'timeout'
require 'json'
require 'zlib'

begin
  require 'factory_authentication'
rescue LoadError
  class FactoryAuthentication
    def factory_api
      nil
    end
    def client
      nil
    end
    def token
      nil
    end
  end
end

class FactoryHttpClient

  def initialize
    @user_agent = "Vespa Factory Client (ruby #{RUBY_VERSION})"
    @auth = FactoryAuthentication.new
  end

  ALL_NET_HTTP_ERRORS = [
    Timeout::Error,  EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, Net::HTTPError,
    Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Errno::EPIPE, Errno::EINVAL, Errno::ECONNRESET,
    Errno::EHOSTUNREACH
  ]

  def request(path, method='GET', body=nil, headers=nil)
    uri = URI(@auth.factory_api + path)
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

    rescue *ALL_NET_HTTP_ERRORS => e
      retry if (retries += 1) < 5
      raise "Could not execute http request after #{retries} retries. Exception: #{e.message}"
    end

    response
  end
end
