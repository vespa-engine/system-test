# Copyright Vespa.ai. All rights reserved.

require 'environment'

module Perf

  # Calculate cpu util for a time period, use start() and end()
  class System
    attr_reader :hostname

    def initialize(node, data = {})
      @node = node
      @hostname = node.hostname
      @data = data
      @start_cpu_used = 0
      @start_cpu_total = 0
      @end_cpu_used = 0
      @end_cpu_total = 0
    end

    # For unit testing
    def initialize(hostname)
      @node = nil
      @hostname = hostname
      @data = {}
      @start_cpu_used = 0
      @start_cpu_total = 0
      @end_cpu_used = 0
      @end_cpu_total = 0
    end

    def cpu_usage
      calculate_cpu_usage(@node.execute("cat /proc/stat"))
    end

    def calulate_cpu_usage(stat_output)
      # See 'man proc_stat' for format. Basically this sums all cpu usage types and subtracts idle time to find cpu used
      stat_output.split("\n").each do |line|
        if line =~ /^cpu /
          values = line.split(' ').collect(&:to_i)
          values.delete(0) # Remove first item ('cpu')
          total = values.inject(:+)
          # Subtract idle time to find cpu usage
          used = total - values[3]

          return [used, total]
        end
      end

      [0, 0]
    end

    def start
      @start_cpu_used, @start_cpu_total = cpu_usage
    end

    def end
      @end_cpu_used, @end_cpu_total = cpu_usage
      set_cpu_util([@start_cpu_used, @start_cpu_total], [@end_cpu_used, @end_cpu_total])
    end

    def set_cpu_util(start_data, end_data)
      cpu_util = (end_data[0] - start_data[0]).to_f / (end_data[1] - start_data[1]).to_f
      @data['cpuutil'] = cpu_util.nan? ? 0.0 : cpu_util
    end

    def cpu_util
      @data['cpuutil']
    end

    def fill
      puts "Filling with #{@data['cpuutil']}"
      Proc.new do |result|
        result.add_metric('cpuutil', @data['cpuutil'], @hostname)
      end
    end
  end
end
