require 'environment'

module Perf

  # Simplified wrapper for h2load benchmarking tool for HTTP/2 servers (https://nghttp2.org/documentation/h2load.1.html)
  class H2Load

    def initialize(node)
      @node = node
    end

    def run_benchmark(clients:, concurrent_streams:, warmup:, duration:,
                      uri_scheme: "https", uri_port: @node.http_port, uri_path: nil, input_file: nil)
      if (uri_path == nil && input_file == nil) || (uri_path != nil && input_file != nil)
        raise "Either 'uripath' or 'input_file' must be specified"
      end

      cmd = "/usr/bin/env h2load --clients=#{clients} --max-concurrent-streams=#{concurrent_streams} --duration=#{duration} "
      cmd += "--warm-up-time=#{warmup} --base-uri=#{uri_scheme}://#{@node.name}:#{uri_port} "

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
      request_latency_items = get_line_items(lines, 'time for request:', ' ')
      min_response_time = to_milliseconds_string(extract_item(request_latency_items[0]))
      max_response_time = to_milliseconds_string(extract_item(request_latency_items[1]))
      mean_response_time = to_milliseconds_string(extract_item(request_latency_items[2]))

      # Mostly the same fillers as fbench wrapper
      filler =
        Proc.new do |result|
          result.add_metric('successfulrequests', successful_requests)
          result.add_metric('minresponsetime', min_response_time)
          result.add_metric('maxresponsetime', max_response_time)
          result.add_metric('avgresponsetime', mean_response_time)
          result.add_metric('qps', qps)
          result.add_parameter('runtime', duration)
          result.add_parameter('clients', clients)
          result.add_parameter('concurrentstreams', concurrent_streams)
          result.add_parameter('loadgiver', 'h2load')
        end
      Result.new(qps, filler)
    end

    def get_line_items(lines, line_prefix, item_delimiter)
      lines.select {|line| line.start_with?(line_prefix) }.first[line_prefix.length..].split(item_delimiter)
    end

    def extract_item(item, index=0)
      item.strip.split(' ')[index]
    end

    def to_milliseconds_string(item)
      if item.end_with?('us')
        (item[..-2].to_f / 1000.0).to_s
      elsif item.end_with?('ms')
        item[..-2]
      elsif item.end_with?('s')
        (item[..-1].to_f * 1000.0).to_s
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
