# Copyright Vespa.ai. All rights reserved.

require 'environment'
require 'performance/stat'

module Perf

  class RemoteProcFs
    def initialize(node)
      @node = node
    end

    def [](name)
      @node.execute("cat /proc/#{name}", :noecho => true)
    rescue
      nil
    end
  end

  # Calculate cpu util for a time period, use start() and end()
  class System
    attr_reader :hostname

    def initialize(node, data = {})
      @node = node
      @hostname = node.hostname unless node == nil
      @data = data
    end

    # For unit testing
    def self.create_for_testing(hostname)
      @hostname = hostname
      new(nil)
    end

    def start
      @system_snapshot_start = Stat::system_snapshot(RemoteProcFs.new(@node))
    end

    def end
      @system_snapshot_end = Stat::system_snapshot(RemoteProcFs.new(@node))
      p = Stat::snapshot_period(@system_snapshot_start, @system_snapshot_end)
      set_cpu_util(p.metrics[:cpu_util])
    end

    def set_cpu_util(cpu_util)
      @data['cpuutil'] = cpu_util.nan? ? 0.0 : cpu_util
    end

    def cpu_util
      @data['cpuutil']
    end

    def fill
      Proc.new do |result|
        result.add_metric('cpuutil', @data['cpuutil'], @hostname)
      end
    end
  end
end
