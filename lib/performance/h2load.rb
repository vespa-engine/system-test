require 'environment'

module Perf

  # Simplified wrapper for h2load benchmarking tool for HTTP/2 servers (https://nghttp2.org/documentation/h2load.1.html)
  # Note: h2load currently does not support client authentication (https://github.com/nghttp2/nghttp2/issues/1479)
  class H2Load

    def initialize(node)
      @node = node
    end

    def run_benchmark(clients:, concurrent_streams:, warmup:, duration:,
                      uri_scheme: "https", uri_port: @node.http_port, uri_path: nil, input_file: nil,
                      post_data_file: nil, protocols: ["h2", "http/1.1"], headers: {}, threads: nil)
      if (uri_path == nil && input_file == nil) || (uri_path != nil && input_file != nil)
        raise "Either 'uripath' or 'input_file' must be specified"
      end

      cmd = "/usr/bin/env h2load --clients=#{clients} --max-concurrent-streams=#{concurrent_streams} --duration=#{duration} "
      cmd += "--warm-up-time=#{warmup} --base-uri=#{uri_scheme}://#{@node.name}:#{uri_port} --npn-list=#{protocols.join(',')} "

      headers.each { |name, value| cmd += "--header=\"#{name}: #{value}\" " }

      cmd += "--threads=#{threads} " if threads != nil
      cmd += "--data=#{post_data_file} " if post_data_file != nil

      if input_file != nil
        cmd += "--input-file=#{input_file} "
      else
        cmd += "#{uri_path} "
      end

      result = @node.execute(cmd)
      lines = result.lines
      summary_items = get_line_items(lines, 'finished in ', ',')
      qps = extract_item(summary_items[1])
      request_items = get_line_items(lines, 'requests:', ',')
      successful_requests = extract_item(request_items[3])
      failed_requests = extract_item(request_items[4])
      request_latency_items = get_line_items(lines, 'time for request:', ' ')
      min_response_time = to_milliseconds_string(extract_item(request_latency_items[0]))
      max_response_time = to_milliseconds_string(extract_item(request_latency_items[1]))
      mean_response_time = to_milliseconds_string(extract_item(request_latency_items[2]))
      status_code_items = get_line_items(lines, 'status codes:', ',')
      responses_2xx = extract_item(status_code_items[0])
      responses_3xx = extract_item(status_code_items[1])
      responses_4xx = extract_item(status_code_items[2])
      responses_5xx = extract_item(status_code_items[3])

      # Mostly the same fillers as fbench wrapper
      filler =
        Proc.new do |result|
          result.add_metric('successfulrequests', successful_requests)
          result.add_metric('failedrequests', failed_requests)
          result.add_metric('minresponsetime', min_response_time)
          result.add_metric('maxresponsetime', max_response_time)
          result.add_metric('avgresponsetime', mean_response_time)
          result.add_metric('2xx', responses_2xx)
          result.add_metric('3xx', responses_3xx)
          result.add_metric('4xx', responses_4xx)
          result.add_metric('5xx', responses_5xx)
          result.add_metric('qps', qps)
          result.add_parameter('runtime', duration)
          result.add_parameter('clients', clients)
          result.add_parameter('threads', threads)
          result.add_parameter('concurrentstreams', concurrent_streams)
          result.add_parameter('loadgiver', 'h2load')
        end
      Result.new(qps, filler)
    end

    def get_line_items(lines, line_prefix, item_delimiter)
      lines.select {|line| line.start_with?(line_prefix) }.first[line_prefix.length..].split(item_delimiter)
    end

    def extract_item(item, index=0)
      item.strip.split(' ')[index].strip
    end

    def to_milliseconds_string(item)
      if item.end_with?('us')
        (item.delete_suffix('us').to_f / 1000.0).to_s
      elsif item.end_with?('ms')
        item.delete_suffix('ms')
      elsif item.end_with?('s')
        (item.delete_suffix('s').to_f * 1000.0).to_s
      else
        raise "Unknown item: #{item}"
      end
    end

    class Result
      attr_reader :filler, :qps

      def initialize(qps, filler)
        @qps = qps
        @filler = filler
      end
    end
  end

end
