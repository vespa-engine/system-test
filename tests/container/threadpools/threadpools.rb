# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class Threadpools < SearchContainerTest

  INT_MAX = 2_147_483_647
  MAX_RETRIES_FETCH_METRICS = 10

  def setup
    set_owner("johsol")
    set_description("Test that thread pools are configurable.")
    @valgrind = false
    deploy(selfdir + "app")
    start
  end

  def test_docproc_handler_threadpool
    expected_threads = available_processors * 1.5
    assert_threadpool("docproc-handler", expected_threads.round, expected_threads.round, "unlimited")
  end

  def test_search_handler_threadpool
    expected_min = available_processors * 1.5
    expected_max = available_processors * 2
    expected_queue = expected_max * 2
    assert_threadpool("search-handler", expected_min.round, expected_max.round, expected_queue.round)
  end

  def test_container_default_threadpool
    expected_min = available_processors * 2
    expected_max = available_processors * 4
    expected_queue = expected_max * 10
    assert_threadpool("default-pool", expected_min.round, expected_max.round, expected_queue.round)
  end

  # Check that threadpool with given name has expected min, max and queue in metrics.
  def assert_threadpool(name, expected_min, expected_max, expected_queue)
    actual_min, actual_max, actual_queue = metrics_threadpool_values(name)
    assert_equal(expected_min, actual_min, "Threadpool '#{name}': expected min=#{expected_min}, got #{actual_min}.")
    assert_equal(expected_max, actual_max, "Threadpool '#{name}': expected max=#{expected_max}, got #{actual_max}.")
    assert_queue(expected_queue, actual_queue, "Threadpool '#{name}': expected queue=#{expected_queue}, got #{actual_queue}.")
  end

  # Assert queue equality as either "unlimited" or Integers.
  def assert_queue(expected_queue, actual_queue, message_on_fail)
    if expected_queue.is_a?(String)
      assert_equal(expected_queue, actual_queue, message_on_fail)
    else
      assert_equal(expected_queue.to_i, actual_queue.to_i, message_on_fail)
    end
  end

  # Returns java runtime available processors on container host.
  def available_processors
    return @available_processors if defined?(@available_processors)

    container = vespa.container.values.first
    out = container.execute(%q{echo "Runtime.getRuntime().availableProcessors();" | jshell -q 2>&1})

    line = out.each_line.find { |l| l.include?('==>') }
    raise "Couldn't find value in jshell output:\n#{out}" unless line

    match = line.match(/==>\s*(\d+)/)
    raise "Non-numeric value in jshell output line: #{line}" unless match

    @available_processors = match[1].to_i
  end

  # Returns the metrics values as a list of json objects from /state/v1/metrics.
  def get_metrics_values
    container = vespa.container.values.first
    last_body = nil

    MAX_RETRIES_FETCH_METRICS.times do
      resp = container.http_get2("/state/v1/metrics")
      assert_equal(200, resp.code.to_i, "Expected 200 but got #{resp.code}")
      last_body = resp.body
      values = JSON.parse(last_body).dig("metrics", "values")
      return values if values.is_a?(Array)
      sleep 1
    end

    flunk "No 'metrics.values' array in metrics response after waiting: #{last_body}"
  end

  # Returns [size, max, queue] where queue is either an Integer or "unlimited" from /state/v1/metrics.
  def metrics_threadpool_values(threadpool_name)
    pool_metrics = get_metrics_values.select do |m|
      m.dig("dimensions", "threadpool") == threadpool_name
    end
    assert(pool_metrics.any?, "No metrics found for threadpool '#{threadpool_name}'")

    size_metric = pool_metrics.find { |m| m["name"] == "jdisc.thread_pool.size" }
    max_metric = pool_metrics.find { |m| m["name"] == "jdisc.thread_pool.max_allowed_size" }
    queue_metric = pool_metrics.find { |m| m["name"] == "jdisc.thread_pool.work_queue.capacity" }

    assert(size_metric, "Missing 'jdisc.thread_pool.size' metric for '#{threadpool_name}'")
    assert(max_metric, "Missing 'jdisc.thread_pool.max_allowed_size' metric for '#{threadpool_name}'")
    assert(queue_metric, "Missing 'jdisc.thread_pool.work_queue.capacity' metric for '#{threadpool_name}'")

    size = (size_metric.dig("values", "last") || size_metric.dig("values", "average")).to_i
    max = (max_metric.dig("values", "last") || max_metric.dig("values", "average")).to_i
    queue = (queue_metric.dig("values", "last") || queue_metric.dig("values", "average")).to_i

    queue_val = queue >= INT_MAX ? "unlimited" : queue
    [size, max, queue_val]
  end

end
