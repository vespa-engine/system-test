# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

module Perf
  class Fbench
    attr_writer :clients, :runtime, :headers, :append_str, :ignore_first, :max_line_size, :single_query_file, :disable_http_keep_alive, :request_per_ms, :times_reuse_query_files, :result_file, :disable_tls, :include_handshake

    def initialize(node, hostname, port)
      @node = node
      @hostname = hostname
      @port = port
      @clients = 1
      @runtime = 60
      @append_str = nil
      @ignore_first = nil
      @max_line_size = nil
      @headers = nil
      @result_file = nil
      @single_query_file = false
      @disable_http_keep_alive = false
      @output = []
      @output_str = nil
      @request_per_ms = 0
      @times_reuse_query_files = nil
      @disable_tls = true
      @include_handshake = true
    end

    def query(queryfile)
      raw_output = @node.execute(fbench_cmd(queryfile))
      @output_str = raw_output
      @output = @node.execute("(echo \"#{raw_output}\" | vespa-fbench-result-filter.pl) 2>&1").split
    end

    def p95
      @output[15]
    end

    # The qps_scale_factor is used to scale up the QPS value,
    # e.g. when calculating the effective QPS for boolean search with subqueries.
    # For the boolean search benchmarking, the number of subqueries per query is used as scale factor.
    def fill(qps_scale_factor = 1)
      Proc.new do |result|
        result.add_metric('loadgiver', 'fbench')
        result.add_metric('runtime', @output[1])
        result.add_metric('successfulrequests', @output[6])
        result.add_metric('minresponsetime', @output[8])
        result.add_metric('maxresponsetime', @output[9])
        result.add_metric('avgresponsetime', @output[10])
        result.add_metric('95 percentile', @output[15])
        result.add_metric('99 percentile', @output[16])
        result.add_metric('qps', (@output[17].to_i * qps_scale_factor).to_s)
        result.add_parameter('clients', @clients)
      end
    end

    def fbench_cmd(queryfile)
      cmd = "#{Environment.instance.vespa_home}/bin/vespa-fbench -c #{@request_per_ms} -s #{@runtime} -n #{@clients} -q #{queryfile} "
      cmd += "-a \"#{@append_str}\" " if @append_str
      cmd += "-i #{@ignore_first} " if @ignore_first
      cmd += "-m #{@max_line_size} " if @max_line_size
      cmd += "-H \"#{@headers}\" " if @headers
      cmd += "-z " if @single_query_file
      cmd += "-o #{@result_file} " if @result_file
      cmd += "-k " if @disable_http_keep_alive
      cmd += "-r #{@times_reuse_query_files} " if @times_reuse_query_files
      cmd += "-D " unless @disable_tls
      cmd += "-i 1 " unless @include_handshake
      cmd += "#{@hostname} #{@port} 2>&1"
      cmd
    end
  end
end
