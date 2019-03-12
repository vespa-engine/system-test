# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'socket'

#
# An implementation of a very naive web server.
# This is used to avoid installing mongrel or other similar ruby web
# servers which require c extensions and so on.
#

module Factory

  # Reponse class keeps all information needed to respond to a
  # request. The developer adds information to this class when generating
  # the web page. The server itself calls the respond method which
  # serves a page to the user which requested the page.
  class WebServerResponse
    include DRb::DRbUndumped

    attr_accessor :body, :request_type, :request
    attr_reader :headers

    @@codes = {
      100 => "Continue",
      101 => "Switching Protocols",
      102 => "Processing",
      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      203 => "Non-Authoritative Information",
      204 => "No Content",
      205 => "Reset Content",
      206 => "Partial Content",
      207 => "Multi-Status",
      300 => "Multiple Choices",
      301 => "Moved Permanently",
      302 => "Found",
      303 => "See Other",
      304 => "Not Modified",
      305 => "Use Proxy",
      306 => "Switch Proxy",
      307 => "Temporary Redirect",
      400 => "Bad Request",
      401 => "Unauthorized",
      402 => "Payment Required",
      403 => "Forbidden",
      404 => "Not Found",
      405 => "Method Not Allowed",
      406 => "Not Acceptable",
      407 => "Proxy Authentication Required",
      408 => "Request Timeout",
      409 => "Conflict",
      410 => "Gone",
      411 => "Length Required",
      412 => "Precondition Failed",
      413 => "Request Entity Too Large",
      414 => "Request-URI Too Long",
      415 => "Unsupported Media Type",
      416 => "Requested Range Not Satisfiable",
      417 => "Expectation Failed",
      418 => "I'm a teapot",
      422 => "Unprocessable Entity",
      423 => "Locked",
      424 => "Failed Dependency",
      425 => "Unordered Collection",
      426 => "Upgrade Required",
      449 => "Retry With",
      450 => "Blocked by Windows Parental Controls",
      500 => "Internal Server Error",
      501 => "Not Implemented",
      502 => "Bad Gateway",
      503 => "Service Unavailable",
      504 => "Gateway Timeout",
      505 => "HTTP Version Not Supported",
      506 => "Variant Also Negotiates",
      507 => "Insufficient Storage",
      509 => "Bandwidth Limit Exceeded",
      510 => "Not Extended",
    }

    def initialize(fd)
      @fd = fd
      @headers = {}
      @body = nil
      @code = 200
      add_header('Content-Type', 'text/html')
    end

    def add_header(name, content)
      @headers[name] = content
    end

    def code=(num)
      raise "Unknown status code #{num}" unless @@codes[num]
      @code = num
    end

    def respond
      add_header('Content-Length', @body.length) unless @headers['Content-Length']
      add_header('Connection', 'close') unless @headers['Connection']
      @fd.send("HTTP/#{@request.http_version} #{@code.to_s} #{@@codes[@code]}\r\n", 0)
      @headers.each do |k,v|
        @fd.send("#{k}: #{v}\r\n", 0)
      end
      @fd.send("\r\n", 0)
      len = @fd.send(@body, 0) if @body
      @fd.flush
      # FIXME: Without this sleep, ruby is failing somehow because client has not read all data.
      sleep 1
      @fd.close
    end
  end

  # The request class contains all the request information.
  class WebServerRequest
    include DRb::DRbUndumped

    attr_accessor :uri, :http_version

    def initialize
      @headers = {}
    end

    def add_header(name, content)
      @headers[name] = content
    end

    def header(name)
      @headers[name]
    end
  end

  # Web server class, contains request parsing and handler dispatching
  class WebServer
    def initialize(port=8080)
      @port = port
      @thread = nil
    end

    def start
      @socket = TCPServer.new(@port)
      @running = true
    end

    def set_handler(&block)
      @handler = block
    end

    def accept
      @thread = Thread.new do
        while @running do
          begin
            fd = @socket.accept
          rescue IOError => error
            raise error if @running
            break
          end
          response = WebServerResponse.new(fd)
          request = WebServerRequest.new

          response.request = request
          request_line = fd.readline

          request_line.gsub!(/[\r\n]*$/, '')
          if request_line =~ /^(\w+)\s([^\s]+)\sHTTP\/(\d+\.\d+)$/
            response.request_type = $1
            request.uri = $2
            request.http_version = $3
            while (line = fd.readline) != "\r\n" and line !~ /^[\r\n]$/
              key, value = line.split(/:\s?/, 2)
              request.add_header(key, value)
            end
            if not @handler
              error(response, 'No handler defined')
            else
              begin
                @handler.call(request, response)
                response.respond
              rescue Exception => error
                error(response, "Handler failed: #{error.inspect}")
              end
            end
          else
            error(response, 'Unable to parse request')
          end
        end
      end
    end

    def stop
      @running = false
      @socket.close
      @thread.terminate
      @thread.join
    end

    def error(response, message=nil)
      response.code = 500;
      response.body = message + "\n"
      response.respond
    end
  end

end

## Sample usage:

#s = Factory::WebServer.new
#a = Proc.new do |request, response|
#  response.add_header('Content-Type', 'text/plain')
#  response.body = "Tried to get: #{request.uri}"
#  if request.uri == '/stop'
#    s.stop
#  end
#end
#s.set_handler(&a)
#
#s.start
#s.accept
