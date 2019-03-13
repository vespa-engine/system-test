# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/httperf_parser'
require 'environment'

module Perf

  class Httperf
    attr_writer :node, :hostname, :port, :output #mandatory
    attr_writer :query_file, :headers, :http_version, :max_connections, :max_piped_calls, :num_calls, :num_conns, :period, :rate, :think_timeout, :timeout
    attr_reader :parser

    def initialize(node, hostname, port)
      @node = node
      @hostname = hostname
      @port = port
      @output = []

      #optional settings:
      @query_file = nil
      @headers = nil
      @http_version = nil
      @max_connections = nil
      @max_piped_called = nil
      @num_calls = nil
      @num_conns = nil
      @period = nil
      @rate = nil
      @think_timeout = nil
      @timeout = nil
      @parser = nil
    end

    def query(uri='/')
      @output = @node.execute(httperf_cmd(uri))
      @parser = HttperfParser.new(@output)
    end

    def fill
      Proc.new do |result|
        result.add_metric('loadgiver', 'httperf')
        result.add_metric('connections', @parser.total_connections)
        result.add_metric('requests', @parser.total_requests)
        result.add_metric('replies', @parser.total_replies)
        result.add_metric('test-duration', @parser.total_test_duration)
        result.add_metric('connection-rate', @parser.connection_rate)
        result.add_metric('connection-latency', @parser.connection_latency)
        result.add_metric('connection-time-min', @parser.connection_time_min)
        result.add_metric('connection-time-avg', @parser.connection_time_avg)
        result.add_metric('connection-time-max', @parser.connection_time_max)
        result.add_metric('connection-time-median', @parser.connection_time_median)
        result.add_metric('connection-time-stddev', @parser.connection_time_stddev)
        result.add_metric('connection-time-connect', @parser.connection_time_connect)
        result.add_metric('connection-length', @parser.connection_length)
        result.add_metric('request-rate', @parser.request_rate)
        result.add_metric('request-latency', @parser.request_latency)
        result.add_metric('request-size', @parser.request_size)
        result.add_metric('reply-rate-min', @parser.reply_rate_min)
        result.add_metric('reply-rate-avg', @parser.reply_rate_avg)
        result.add_metric('reply-rate-max', @parser.reply_rate_max)
        result.add_metric('reply-rate-stddev', @parser.reply_rate_stddev)
        result.add_metric('reply-time-avg-firstbyte', @parser.reply_time_avg_firstbyte)
        result.add_metric('reply-time-avg-transfer', @parser.reply_time_avg_transfer)
        result.add_metric('reply-time-avg-total', @parser.reply_time_avg_total)
        result.add_metric('reply-size-header', @parser.reply_size_header)
        result.add_metric('reply-size-content', @parser.reply_size_content)
        result.add_metric('reply-size-footer', @parser.reply_size_footer)
        result.add_metric('reply-size-total', @parser.reply_size_total)
        result.add_metric('reply-status-1xx', @parser.reply_status_1xx)
        result.add_metric('reply-status-2xx', @parser.reply_status_2xx)
        result.add_metric('reply-status-3xx', @parser.reply_status_3xx)
        result.add_metric('reply-status-4xx', @parser.reply_status_4xx)
        result.add_metric('reply-status-5xx', @parser.reply_status_5xx)
        result.add_metric('errors-total', @parser.errors_total)
        result.add_metric('errors-client-timo', @parser.errors_client_timo)
        result.add_metric('errors-socket-timo', @parser.errors_socket_timo)
        result.add_metric('errors-connrefused',@parser.errors_connrefused)
        result.add_metric('errors-connreset', @parser.errors_connreset)
        result.add_metric('errors-fd-unavail', @parser.errors_fd_unavail)
        result.add_metric('errors-addrunavail', @parser.errors_addrunavail)
        result.add_metric('errors-ftab-full', @parser.errors_ftab_full)
        result.add_metric('errors-other', @parser.errors_other)
      end
    end

    def httperf_cmd(uri)
      cmd = "(#{Environment.instance.vespa_home}/bin/httperf --hog --server=#{@hostname} --port=#{@port}"

      cmd += " --uri=#{uri}"
      cmd += " --wlog=y,#{@queryfile}" if @queryfile
      cmd += " --add-header=#{@headers} " if @headers
      cmd += " --http-version=#{@http_version} " if @http_version
      cmd += " --max-connections=#{@max_connections} " if @max_connections
      cmd += " --max-piped-calls=#{@max_piped_calls} " if @max_piped_calls
      cmd += " --num-calls=#{@num_calls} " if @num_calls
      cmd += " --num-conns=#{@num_conns} " if @num_conns
      cmd += " --period=#{@period} " if @period
      cmd += " --rate=#{@rate} " if @rate
      cmd += " --think-timeout=#{@think_timeout} " if @think_timeout
      cmd += " --timeout=#{@timeout} " if @timeout
      cmd += " --client=0/1 ) 2>&1"
    end
  end
end
