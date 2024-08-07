# Copyright Vespa.ai. All rights reserved.

require 'environment'

module Perf
  class ConfigLoadTester
    attr_writer :threads, :numiter
    def initialize(node_to_run_on, hostname, port, defdir)
      @node_to_run_on = node_to_run_on
      @hostname = hostname
      @port = port
      @defdir = defdir
      @res = []
      @output = "n/a"
    end

    def run(filename=nil, debug=false)
      output = nil
      @output = @node_to_run_on.execute(cmd(filename, debug))
      puts "Loadtester output:\n#{@output}"
      # Loop through output, skipping #comments
      @output.split("\n").each do |line|
        if line=~/^#/
          # comment
        else
          # result printout, store this
          @res = line.gsub(/\s+/, "").split(",")
        end
      end
      puts "Loadtester results:\n#{@res}"
    end

    def run_bg(filename=nil)
      @pid = @node_to_run_on.execute_bg(cmd(filename, false))
    end

    def cmd(filename, debug)
      "#{Environment.instance.vespa_home}/bin/vespa-config-loadtester -c #{@hostname} -p #{@port} -t #{@threads} -i #{@numiter} -l #{filename} -dd #{@defdir} #{debug ? '-d' : ''}"
    end

    def stop
      if (@pid) then
        puts "Stopping load tester with pid #{@pid}"
        @node_to_run_on.kill_pid(@pid)
      end
    end

    def fill
      Proc.new do |result|
        result.add_parameter('config.loadtester.num_threads', @threads)
        result.add_parameter('config.loadtester.num_queries', @numiter)

        result.add_metric('config.loadtester.req_per_sec', @res[0])
        result.add_metric('config.loadtester.avg_latency', @res[1])
        result.add_metric('config.loadtester.min_latency', @res[2])
        result.add_metric('config.loadtester.max_latency', @res[3])
      end
    end
  end
end
