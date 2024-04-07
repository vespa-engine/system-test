# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'net/http'

class StatusPages < IndexedStreamingSearchTest
    MAX_RETRIES = 30

    def setup
      set_owner("musum")
      set_description("Validate that services container/qrs has statuspages available")
      deploy_app(SearchApp.new.sd(SEARCH_DATA+'music.sd'))
      start
    end

    def assert_web_page(host, port, doc, code, msg, substring)
      retries = MAX_RETRIES
      begin
        up = false
        while !up
          response = https_client.get(host, port, doc)
          if response
            up = true
          end
          # puts "Code = #{response.code}"
          # puts "Message = #{response.message}"
          # response.each {|key, val| printf "%-14s = %-40.40s\n", key, val }
          # puts "body>>> #{response.body} <<<body"
          assert_equal(code, response.code)
          assert_equal(msg, response.message)
          assert(response.body.index(substring),
                 "Could not find substring '#{substring}' in webpage.")
        end
      rescue SystemCallError
        if retries == MAX_RETRIES
          output("\nError connecting to #{host}:#{port} :\n #{$!}\nRetrying.", false)
        end
        output(".", false)
        sleep 1
        if retries > 0
          retries = retries - 1
          retry
        else
          raise
        end
      end
    end

    def assert_status_down(host, port)
      assert_web_page(host, port, '/status.html', '404', 'Not Found', 'No search backends available')
    end

    def assert_status_ok(host, port)
      assert_web_page(host, port, '/status.html', '200', 'OK', 'OK')
    end

    def test_statuspages
      puts "Checking that qrservers have status pages offline"
      vespa.qrserver.each { |index, node|
        assert_status_ok(node.name, node.http_port)
      }
      feed(:file => SEARCH_DATA+"music.10.json")
      wait_for_hitcount("query=sddocname:music", 10)
      sleep 3
      puts "Checking that qrservers have status pages online"
      vespa.qrserver.each { |index, node|
        assert_status_ok(node.name, node.http_port)
      }
    end

    def teardown
      stop
    end

end
