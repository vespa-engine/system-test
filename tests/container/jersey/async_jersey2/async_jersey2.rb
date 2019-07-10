# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'app_generator/container_app'
require 'app_generator/rest_api'
require 'container_test'
require 'thread'

class AsyncJersey2 < ContainerTest
  include AppGenerator

  def setup
    set_owner("nobody")
    set_description("Verify that the async functionality in jersey2 works.")

    add_bundle_dir(selfdir + "async", "async_jersey2")

    app = ContainerApp.new.container(
            Container.new.
              config(ConfigOverride.new(:"jdisc.http.server").
                add("maxWorkerThreads", 15)).
              rest_api(RestApi.new("rest-api").
                bundle(Bundle.new("async_jersey2"))))

    start(app)
  end

  def test_async_jersey2
    async_should_work
    sync_should_fail
  end

  def async_should_work
    path = "/rest-api/async"
    numRequest = 200

    successfulRequests = multiple_http_get_requests(path, numRequest)
    assert(successfulRequests > 2/3.to_f * numRequest, "Most of the requests should succeed.")
  end

  def sync_should_fail
    path = "/rest-api/sync"
    numRequest = 200

    successfulRequests = multiple_http_get_requests(path, numRequest)
    assert(successfulRequests < 1/3.to_f * numRequest, "Most of the requests should time out.")
  end


  def multiple_http_get_requests(path, numRequests)
    readTimeoutInSeconds = 30

    mutex = Mutex.new
    successfulRequests = 0

    threads = (1..numRequests).map do
      Thread.new do
        begin
          https_client.with_https_connection(@container.hostname, @container.http_port, path) do |conn, _|
            header = {}
            conn.read_timeout = readTimeoutInSeconds
            result = conn.get(path, header)

            if result.body == "Slow response"
              mutex.synchronize { successfulRequests += 1 }
            end
          end
        rescue Timeout::Error
          # do nothing
        rescue Errno::ECONNREFUSED
          # Connection refused, included because the test was unstable
        rescue DRb::DRbConnError
          # Connection reset by peer, included because the test was unstable
        end
      end
    end
    threads.each {|t| t.join}

    puts "Successful requests: " + successfulRequests.to_s + " of " + numRequests.to_s
    return successfulRequests
  end

  def teardown
    stop
  end

end
