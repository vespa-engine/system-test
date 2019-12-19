# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

class VespaCleanup

  def initialize(testcase, cmd_args)
    @testcase = testcase
    @cmd_args = cmd_args
  end

  def clean(nodes)
    if @cmd_args[:nopreclean]
      @testcase.puts "Pre-start cleaning has been turned off"
      return
    end
    @testcase.output("DEBUG: Running cleanup")
    puts "Running cleanup"
    kill_stale_processes(nodes)
    nodes.each do |hostname, node|
      clean_search(node)
      clean_configserver(node)
    end
  end

  def clean_search(node)
    execute(node, "rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/*")
  end

  def clean_configserver(node)
    execute(node, "vespa-configserver-remove-state -force")
    execute(node, "rm -rf #{Environment.instance.vespa_home}/tmp/config-models")
    execute(node, "rm -f #{Environment.instance.vespa_home}/config/configserer-app/components/config-model-fat*jar")
  end

  def kill_stale_processes(nodes)
    if @cmd_args[:nostop] or (@cmd_args[:nostop_if_failure] && @testcase.failure_recorded)
      puts "Nostop set, won't kill stale processes"
      return
    end

    find_and_kill_stale_processes(nodes, Time.now, 'TERM')
    find_and_kill_stale_processes(nodes, Time.now, 'KILL')
  end

  def find_and_kill_stale_processes(nodes, time_started, signal)
    nodes.each do |hostname, node|
      pids = collect_stale_processes(node)
      break if (pids.size == 0 or (Time.now - time_started) > 2)

      @testcase.output("Found #{pids.size} stale Vespa processes for #{hostname}, killing them with signal #{signal}")
      kill = "kill -s #{signal} #{pids.join(' ')}"
      execute(node, kill)
    end
  end

  def collect_stale_processes(node)
    pids = []
    ps_output = execute(node, "ps auxww | grep vespa | grep -v grep")
    ps_output.split("\n").each { |process_line|
      pids << process_line.split[1]
    }
    pids
  end

  def remove_model_plugins(nodes)
    nodes.each do |node|
      execute(node, "rm -rf #{Environment.instance.vespa_home}/conf/configserver-app/config-models/*")
    end
  end

  private

  def execute(node, cmd)
    node.execute(cmd, :exceptiononfailure => false)
  end
end
