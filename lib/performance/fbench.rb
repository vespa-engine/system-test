# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

module Perf
  class Fbench
    attr_writer :clients, :runtime, :headers, :append_str, :ignore_first, :max_line_size, :single_query_file, :disable_http_keep_alive,
                :use_post, :request_per_ms, :times_reuse_query_files, :result_file, :disable_tls, :include_handshake,
                :certificate_file, :private_key_file, :ca_certificate_file

    def initialize(node, hostname, port)
      @node = node
      @hostname = hostname
      @port = port
      @clients = 1
      @runtime = 60
      @append_str = nil
      @ignore_first = nil
      @max_line_size = nil
      @use_post = false
      @headers = nil
      @result_file = nil
      @single_query_file = false
      @disable_http_keep_alive = false
      @output = []
      @output_str = nil
      @request_per_ms = 0
      @times_reuse_query_files = nil
      @disable_tls = false
      @include_handshake = true
      @certificate_file = nil
      @ca_certificate_file = nil
      @private_key_file = nil
    end

    def query(queryfile)
      result_file = @node.create_unique_temp_file('fbench_result_')
      raw_output = @node.execute("#{fbench_cmd(queryfile)} | tee #{result_file}")
      @output_str = raw_output
      @output = @node.execute("cat #{result_file} | (sed -n 's/.*: *\([0-9.][0-9.]*\).*/\1/p' | tr '\n' ' ';echo)").split
    end

    def p95
      @output[15]
    end

    # The qps_scale_factor is used to scale up the QPS value,
    # e.g. when calculating the effective QPS for boolean search with subqueries.
    # For the boolean search benchmarking, the number of subqueries per query is used as scale factor.
    def qps(qps_scale_factor = 1)
      @output[23].to_f * qps_scale_factor
    end

    def http_status_code_distribution
      hist = {}
      @output_str.each_line do |line|
        if line =~ /\s+(\d+)\s+:\s+(\d+)/
          hist[$~[1].to_i] = $~[2].to_i
        end
      end
      hist
    end

    # The qps_scale_factor is used to scale up the QPS value,
    # e.g. when calculating the effective QPS for boolean search with subqueries.
    # For the boolean search benchmarking, the number of subqueries per query is used as scale factor.
    def fill(qps_scale_factor = 1)
      Proc.new do |result|
        result.add_metric('runtime', @output[1])
        result.add_metric('successfulrequests', @output[6])
        result.add_metric('minresponsetime', @output[8])
        result.add_metric('maxresponsetime', @output[9])
        result.add_metric('avgresponsetime', @output[10])
        result.add_metric('95 percentile', @output[15])
        result.add_metric('99 percentile', @output[17])
        result.add_metric('qps', qps(qps_scale_factor).to_s)
        result.add_parameter('clients', @clients)
        result.add_parameter('loadgiver', 'fbench')
      end
    end

    def fbench_cmd(queryfile)
      cmd = "#{Environment.instance.vespa_home}/bin/vespa-fbench -c #{@request_per_ms} -s #{@runtime} -n #{@clients} -q #{queryfile} "
      cmd += "-a \"#{@append_str}\" " if @append_str
      cmd += "-i #{@ignore_first} " if @ignore_first
      cmd += "-m #{@max_line_size} " if @max_line_size
      cmd += "-P " if @use_post
      cmd += "-H \"#{@headers}\" " if @headers
      cmd += "-z " if @single_query_file
      cmd += "-o #{@result_file} " if @result_file
      cmd += "-k " if @disable_http_keep_alive
      cmd += "-r #{@times_reuse_query_files} " if @times_reuse_query_files
      cmd += "-D " unless @disable_tls
      cmd += "-i 1 " unless @include_handshake
      cmd += "-T #{@ca_certificate_file} " if @ca_certificate_file
      cmd += "-C #{@certificate_file} " if @certificate_file
      cmd += "-K #{@private_key_file} " if @private_key_file
      cmd += "#{@hostname} #{@port} 2>&1"
      cmd
    end
  end
end
