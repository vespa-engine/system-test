# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
module RestApi

  def http_request_post(uri, params = {})
    req = Net::HTTP::Post.new(uri.request_uri, initheader = params[:headers])
    http_request(uri, { :request => req }.merge(params))
  end

  def http_request_get(uri, params = {})
    req = Net::HTTP::Get.new(uri.request_uri)
    http_request(uri, { :request => req }.merge(params))
  end

  def http_request_put(uri, params = {})
    req = Net::HTTP::Put.new(uri.request_uri, initheader=params[:headers])
    http_request(uri, { :request => req }.merge(params))
  end

  def http_request_delete(uri, params = {})
    req = Net::HTTP::Delete.new(uri.request_uri)
    http_request(uri, { :request => req }.merge(params))
  end

  #
  # HTTP requests and response assertions
  #
  def http_request(original_uri, params)
    max_iterations = 30
    iterations = 0
    response = nil
    while iterations < max_iterations do
      @https_client.with_https_connection(original_uri.host, original_uri.port, original_uri.path, original_uri.query) do |conn, uri|
        begin
          conn.open_timeout = params[:open_timeout] ? params[:open_timeout] : 4 * 60
          conn.read_timeout = params[:read_timeout] ? params[:read_timeout] : 4 * 60
          if params[:request]
            request = params[:request]
          else
            request = Net::HTTP::Get.new uri.request_uri
          end
          if params[:body]
            request.body = params[:body]
          end
          puts "Request: " + request.method + " " + uri.to_s
          response = conn.request(request)
          break
        rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
          puts "Error: #{$!}, url=#{uri}"
          if iterations == max_iterations - 1
            puts("Request failed after #{max_iterations} attempts: #{$!}, url=#{uri}")
            raise
          else
            sleep 1
          end
        end
      end
      iterations += 1
    end
    puts "Response: #{response.inspect}"
    response
  end

  def get_json(response)
    JSON.parse(response.body) if response
  end

end
