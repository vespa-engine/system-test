# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
module RestApi

  def http_request_post(uri, params = {})
    http_request(uri, { :request => Net::HTTP::Post }.merge(params))
  end

  def http_request_get(uri, params = {})
    http_request(uri, { :request => Net::HTTP::Get }.merge(params))
  end

  def http_request_put(uri, params = {})
    http_request(uri, { :request => Net::HTTP::Put }.merge(params))
  end

  def http_request_delete(uri, params = {})
    http_request(uri, { :request => Net::HTTP::Delete }.merge(params))
  end

  #
  # HTTP requests and response assertions
  #
  def http_request(original_uri, params)
    max_iterations = 60
    iterations = 0
    response = nil
    while iterations < max_iterations do
      begin
        @https_client.with_https_connection(original_uri.host, original_uri.port, original_uri.path, query: original_uri.query) do |conn, uri|
          conn.open_timeout = params[:open_timeout] ? params[:open_timeout] : 4 * 60
          conn.read_timeout = params[:read_timeout] ? params[:read_timeout] : 4 * 60
          if params[:request]
            request = params[:request].new(uri, params[:headers])
          else
            request = Net::HTTP::Get.new uri.request_uri
          end
          if params[:body]
            request.body = params[:body]
          end
          puts "Request: " + request.method + " " + request.uri.to_s
          response = conn.request(request)
        end
        break
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
        puts "Error: #{$!}, url=#{original_uri}"
        if iterations == max_iterations - 1
          puts("Request failed after #{max_iterations} attempts: #{$!}, url=#{original_uri}")
          raise
        else
          sleep 1
        end
      end
      iterations += 1
    end
    #puts "Response: #{response.inspect}"
    response
  end

  def get_json(response)
    JSON.parse(response.body) if response
  end

end
