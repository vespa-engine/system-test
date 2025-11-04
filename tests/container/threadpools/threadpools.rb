# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class Threadpools < SearchContainerTest

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
    assert_threadpool("search-handler", expected_min.round, expected_max.round, expected_queue.round.to_s)
  end

  # Check that threadpool with name has expected min max and queue in log
  def assert_threadpool(name, expected_min, expected_max, expected_queue)
    line = find_threadpool_log(name)
    actual_min, actual_max, actual_queue = extract_threadpool_values(line)

    assert_equal(expected_min, actual_min,
                 "Threadpool '#{name}': expected min=#{expected_min}, got #{actual_min}. Line: #{line}")
    assert_equal(expected_max, actual_max,
                 "Threadpool '#{name}': expected max=#{expected_max}, got #{actual_max}. Line: #{line}")
    assert_equal(expected_queue, actual_queue,
                 "Threadpool '#{name}': expected queue=#{expected_queue}, got #{actual_queue}. Line: #{line}")
  end

  # Returns java runtime available processors on container host
  def available_processors
    container = vespa.container.values.first
    out = container.execute(%q{echo "Runtime.getRuntime().availableProcessors();" | jshell -q 2>&1})

    line = out.each_line.find { |l| l.include?('==>') }
    raise "Couldn't find value in jshell output:\n#{out}" unless line

    match = line.match(/==>\s*(\d+)/)
    raise "Non-numeric value in jshell output line: #{line}" unless match

    match[1].to_i
  end

  # Finds the threadpool log line for given name, expects only 1 line, returns that line.
  def find_threadpool_log(name)
    escaped_name = Regexp.escape(name)
    threadpool_name = /Threadpool\s+'#{escaped_name}'[^\n]*/ix
    lines = vespa.logserver.find_log_matches(threadpool_name, {})
    assert_equal(1, lines.size, "Expected only one instance of '#{name}' got #{lines.size}.\n#{lines}")
    lines.first
  end

  # Extracts min, max and queue values from the line.
  def extract_threadpool_values(line)
    min_s = line[/\bmin\s*=\s*(\d+)\b/i, 1] # integer
    max_s = line[/\bmax\s*=\s*(\d+)\b/i, 1] # integer
    queue_s = line[/\bqueue\s*=\s*([^,\s]+)\b/i, 1] # e.g. "unlimited" or integer

    assert(min_s, "Couldn't find min=... on line: #{line}")
    assert(max_s, "Couldn't find max=... on line: #{line}")
    assert(queue_s, "Couldn't find queue=... on line: #{line}")

    actual_min = Integer(min_s)
    actual_max = Integer(max_s)
    actual_queue = queue_s.downcase

    [actual_min, actual_max, actual_queue]
  end

end
