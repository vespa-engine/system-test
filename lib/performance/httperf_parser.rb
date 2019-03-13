# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
module Perf
  class HttperfParser

    def initialize(httperf_output)
      @output = httperf_output
    end

    def total_connections
      @output.match '^Total: connections ([\d]+)'
      $1.to_i
    end

    def total_requests
      @output.match '^Total: .* requests ([\d]+)'
      $1.to_i
    end

    def total_replies
      @output.match '^Total: .* replies ([\d]+)'
      $1.to_i
    end

    def total_test_duration
      @output.match '^Total: .* test-duration ([\d\.]+)'
      $1.to_f
    end

    def connection_rate
      @output.match '^Connection rate: ([\d\.]+)'
      $1.to_f
    end

    def connection_latency
      @output.match '^Connection rate: .* \(([\d\.]+)'
      $1.to_f
    end

    def connection_time_min
      @output.match '^Connection time \[ms\]: min ([\d\.]+)'
      $1.to_f
    end

    def connection_time_avg
      @output.match '^Connection time \[ms\]: .* avg ([\d\.]+)'
      $1.to_f
    end

    def connection_time_max
      @output.match '^Connection time \[ms\]: .* max ([\d\.]+)'
      $1.to_f
    end

    def connection_time_median
      @output.match '^Connection time \[ms\]: .* median ([\d\.]+)'
      $1.to_f
    end

    def connection_time_stddev
      @output.match '^Connection time \[ms\]: .* stddev ([\d\.]+)'
      $1.to_f
    end

    def connection_time_connect
      @output.match '^Connection time \[ms\]: connect ([\d\.]+)'
      $1.to_f
    end

    def connection_length
      @output.match '^Connection length \[replies\/conn\]: ([\d\.]+)'
      $1.to_f
    end

    def request_rate
      @output.match '^Request rate: ([\d\.]+)'
      $1.to_f
    end

    def request_latency
      @output.match '^Request rate: .* \(([\d\.]+)'
      $1.to_f
    end

    def request_size
      @output.match '^Request size \[B\]: ([\d\.]+)'
      $1.to_f
    end


    def reply_rate_min
      @output.match '^Reply rate.*min ([\d\.]+)'
      $1.to_f
    end

    def reply_rate_avg
      @output.match '^Reply rate.*avg ([\d\.]+)'
      $1.to_f
    end

    def reply_rate_max
      @output.match '^Reply rate.*max ([\d\.]+)'
      $1.to_f
    end

    def reply_rate_stddev
      @output.match '^Reply rate.*stddev ([\d\.]+)'
      $1.to_f
    end

    def reply_time_avg_firstbyte
      @output.match '^Reply time \(avg\) .* first-byte response ([\d\.]+)'
      ret = $1.to_f

      # Resolution is only 0.1 ms, so when lower than 0.05, httperf returns 0.0
      ret > 0.0 ? ret : 0.05
    end

    def reply_time_avg_transfer
      @output.match '^Reply time \(avg\) .* transfer ([\d\.]+)'
      $1.to_f
    end

    def reply_time_avg_total
      @output.match '^Reply time \(avg\) .* total ([\d\.]+)'
      $1.to_f
    end

    def reply_size_header
      @output.match '^Reply size \[B\]: header ([\d\.]+)'
      $1.to_f
    end

    def reply_size_content
      @output.match '^Reply size \[B\]: .* content ([\d\.]+)'
      $1.to_f
    end

    def reply_size_footer
      @output.match '^Reply size \[B\]: .* footer ([\d\.]+)'
      $1.to_f
    end

    def reply_size_total
      @output.match '^Reply size \[B\]: .* \(total ([\d\.]+)'
      $1.to_f
    end

    def reply_status_1xx
      @output.match '^Reply status: 1xx\=([\d]+)'
      $1.to_i
    end

    def reply_status_2xx
      @output.match '^Reply status: .* 2xx\=([\d]+)'
      $1.to_i
    end

    def reply_status_3xx
      @output.match '^Reply status: .* 3xx\=([\d]+)'
      $1.to_i
    end

    def reply_status_4xx
      @output.match '^Reply status: .* 4xx\=([\d]+)'
      $1.to_i
    end

    def reply_status_5xx
      @output.match '^Reply status: .* 5xx\=([\d]+)'
      $1.to_i
    end

    def errors_total
      @output.match '^Errors: total ([\d]+)'
      $1.to_i
    end

    def errors_client_timo
      @output.match '^Errors: .* client-timo ([\d]+)'
      $1.to_i
    end

    def errors_socket_timo
      @output.match '^Errors: .* socket-timo ([\d]+)'
      $1.to_i
    end

    def errors_connrefused
      @output.match '^Errors: .* connrefused ([\d]+)'
      $1.to_i
    end

    def errors_connreset
      @output.match '^Errors: .* connreset ([\d]+)'
      $1.to_i
    end

    def errors_fd_unavail
      @output.match '^Errors: fd-unavail ([\d]+)'
      $1.to_i
    end

    def errors_addrunavail
      @output.match '^Errors: .* addrunavail ([\d]+)'
      $1.to_i
    end

    def errors_ftab_full
      @output.match '^Errors: .* ftab\-full ([\d]+)'
      $1.to_i
    end

    def errors_other
      @output.match '^Errors: .* other ([\d]+)'
      $1.to_i
    end

  end
end
