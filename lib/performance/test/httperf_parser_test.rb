# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'
require '../httperf_parser'

class HttperfParserTest < Test::Unit::TestCase
  include Perf

  def get_path(filename)
    File.join(File.dirname(__FILE__), filename)
  end

  def read_file(filename)
    File.read(get_path(filename))
  end

  def setup
    @output = read_file('httperf_output.txt')
    @parser = HttperfParser.new(@output)
  end

  def test_total_connections
    assert_equal(60000, @parser.total_connections)
  end

  def test_total_requests
    # Note that the number is manipulated in the file to make the test meaningful (was: 60000)
    assert_equal(50000, @parser.total_requests)
  end

  def test_total_replies
    # Note that the number is manipulated in the file to make the test meaningful (was: 60000)
    assert_equal(40000, @parser.total_replies)
  end

  def test_total_test_duration
    assert_equal(15.525, @parser.total_test_duration)
  end

  def test_connection_rate
    assert_equal(3864.7, @parser.connection_rate)
  end

  def test_connection_latency
    assert_equal(0.3, @parser.connection_latency)
  end

  def test_connection_time_min
    assert_equal(0.2, @parser.connection_time_min)
  end

  def test_connection_time_avg
    assert_equal(0.3, @parser.connection_time_avg)
  end

  def test_connection_time_max
    assert_equal(6.8, @parser.connection_time_max)
  end

  def test_connection_time_median
    assert_equal(0.5, @parser.connection_time_median)
  end

  def test_connection_time_stddev
    assert_equal(0.2, @parser.connection_time_stddev)
  end

  def test_connection_time_connect
    assert_equal(0.1, @parser.connection_time_connect)
  end

  def test_connection_length
    assert_equal(1.000, @parser.connection_length)
  end

  def test_request_rate
    assert_equal(3864.8, @parser.request_rate)
  end

  def test_request_latency
    assert_equal(0.3, @parser.request_latency)
  end

  def test_request_size
    assert_equal(83.0, @parser.request_size)
  end

  def test_reply_rate_min
    assert_equal(3825.9, @parser.reply_rate_min)
  end

  def test_reply_rate_avg
    assert_equal(3867.2, @parser.reply_rate_avg)
  end

  def test_reply_rate_max
    assert_equal(3890.7, @parser.reply_rate_max)
  end

  def test_reply_rate_stddev
    assert_equal(35.9, @parser.reply_rate_stddev)
  end

  def test_reply_time_avg_firstbyte
    assert_equal(0.2, @parser.reply_time_avg_firstbyte)
  end

  def test_reply_time_avg_transfer
    assert_equal(0.2, @parser.reply_time_avg_firstbyte)
  end

  def test_reply_time_avg_total
    assert_equal(0.22, @parser.reply_time_avg_total)
  end

  def test_reply_size_header
    assert_equal(182.0, @parser.reply_size_header)
  end

  def test_reply_size_content
    assert_equal(13.0, @parser.reply_size_content)
  end

  def test_reply_size_footer
    assert_equal(2.0, @parser.reply_size_footer)
  end

  def test_reply_size_total
    assert_equal(197.0, @parser.reply_size_total)
  end

  def test_reply_status_1xx
    assert_equal(0, @parser.reply_status_1xx)
  end

  def test_reply_status_2xx
    assert_equal(60000, @parser.reply_status_2xx)
  end

  def test_reply_status_3xx
    assert_equal(3, @parser.reply_status_3xx)
  end

  def test_reply_status_4xx
    assert_equal(4, @parser.reply_status_4xx)
  end

  def test_reply_status_5xx
    assert_equal(5, @parser.reply_status_5xx)
  end

  def test_errors_total
    assert_equal(30, @parser.errors_total)
  end

  def test_errors_client_timo
    assert_equal(6, @parser.errors_client_timo)
  end

  def test_errors_socket_timo
    assert_equal(7, @parser.errors_socket_timo)
  end

  def test_errors_connrefused
    assert_equal(8, @parser.errors_connrefused)
  end

  def test_errors_connreset
    assert_equal(9, @parser.errors_connreset)
  end

  def test_errors_fd_unavail
    assert_equal(11, @parser.errors_fd_unavail)
  end

  def test_errors_addrunavail
    assert_equal(12, @parser.errors_addrunavail)
  end

  def test_errors_ftab_full
    assert_equal(13, @parser.errors_ftab_full)
  end

  def test_errors_other
    assert_equal(14, @parser.errors_other)
  end
end
