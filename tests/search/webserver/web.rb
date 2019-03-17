# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'net/http'
require 'uri'

require 'indexed_search_test'

class WebServer < IndexedSearchTest

  def setup
    set_owner("aressem")
    set_description("Test the mock http server in systemtests")

    # deploy is required to have nodeproxied properly initialized.
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"simple.sd"))
    start
  end

  def disabled_test_server
    vespa.nodeproxies.each do |host, p|
      p.http_server_make(1025)
      counter = 0
      p.http_server_handler(1025) do |request, response|
        if request.uri == '/'
          response.body = 'foo'
        elsif request.uri == '/counter'
          counter += 1
          response.body = "#{counter}"
        elsif request.uri == '/file'
          response.body = File.read(SEARCH+'webserver/index.html')
        end
      end

      p.http_server_start(1025)
      puts "Hostname is #{host}"
      data = Net::HTTP.get(URI.parse("http://#{host}:1025/"))
      assert_equal('foo', data, 'Index page does not match')
      data = Net::HTTP.get(URI.parse("http://#{host}:1025/counter"))
      assert_equal(1, data.to_i, 'Count is wrong')
      data = Net::HTTP.get(URI.parse("http://#{host}:1025/counter"))
      assert_equal(2, data.to_i, 'Count is wrong')
      assert_equal(File.read(SEARCH+'webserver/index.html'),
                   Net::HTTP.get(URI.parse("http://#{host}:1025/file")),
                   'File content does not match')

      p.http_server_make(8081)
      p.http_server_handler(8081) do |request, response|
        response.body = 'bar'
      end
      p.http_server_start(8081)
      data = Net::HTTP.get(URI.parse("http://#{host}:8081/"))
      assert_equal('bar', data, 'Index page does not match')
      p.http_server_stop(8081)
      p.http_server_stop(1025)
      begin
        Net::HTTP.get(URI.parse("http://#{host}:8081/"))
        assert(false, '8081 web server not stopped')
      rescue Errno::ECONNREFUSED
      end
      begin
        Net::HTTP.get(URI.parse("http://#{host}:1025/"))
        assert(false, '1025 web server not stopped')
      rescue Errno::ECONNREFUSED
      end
    end
  end

  def teardown
    stop
  end

end
