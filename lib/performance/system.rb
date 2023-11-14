# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

module Perf

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
      @ysar_binary = propose_ysar_gather # TODO Remove dependency on internal tooling
    end

    def propose_ysar_gather
      @ysar_binary = "#{Environment.instance.vespa_home}/sbin/ysar_gather"
      @ysar_binary = "/usr/sbin/ysar_gather" unless has_ysar
    end

    def has_ysar
      @node.file?(@ysar_binary)
    end

    def ysar_gather_cmd
      "#{@ysar_binary} --list --delay-mode=none"
    end

    def load
      unless has_ysar
        return [0, 0]
      end
      output = @node.execute(ysar_gather_cmd, :noecho => true)
      output.split("\n").each do |l|
        if l =~ /^cput=/
          key,value = l.split('=')
          values = value.split(',').collect(&:to_i)

          total = values.inject(:+)
          used = total - values[4]

          return [used, total]
        end
      end

      return [0, 0]
    end

    def start
      @start_cpu_used, @start_cpu_total = load
    end

    def end
      @end_cpu_used, @end_cpu_total = load
      cpu_util = (@end_cpu_used - @start_cpu_used).to_f / (@end_cpu_total - @start_cpu_total)
      @data['cpuutil'] = cpu_util.nan? ? 0.0 : cpu_util
    end

    def fill
      Proc.new do |result|
        result.add_metric('cpuutil', @data['cpuutil'], @hostname)
      end
    end
  end
end
