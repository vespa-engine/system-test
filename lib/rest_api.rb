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
  def http_request(uri, params)
    proxy_host = params[:proxy_host]
    proxy_port = params[:proxy_port]
    if proxy_host
      puts "Using http proxy #{proxy_host}:#{proxy_port}"
    end
    max_iterations = 30
    iterations = 0
    response = nil
    while iterations < max_iterations do
      begin
        Net::HTTP::Proxy(proxy_host, proxy_port).start(uri.host, uri.port) do |http|
          http.open_timeout = params[:open_timeout] ? params[:open_timeout] : 4 * 60
          http.read_timeout = params[:read_timeout] ? params[:read_timeout] : 4 * 60
          if (params[:request])
#            puts ":request in params #{params[:request]}"
            request = params[:request]
          else
            request = Net::HTTP::Get.new uri.request_uri
          end
          if (params[:body])
            request.body = params[:body]
          end
          puts "Request: " + request.method + " " + uri.to_s
          response = http.request(request)
        end
        break
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
        puts "Error: #{$!}, url=#{uri}"
        if (iterations == max_iterations - 1)
          puts("Request failed after #{max_iterations} attempts: #{$!}, url=#{uri}")
          raise 
        else
          sleep 1
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
