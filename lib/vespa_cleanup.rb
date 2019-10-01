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
    nodes.each do |hostname, node|
      pids = []
      badpids = []
      user = Environment.instance.vespa_user
      pids |= collect_stale_pids(node, "ps auxww | grep vespa-feeder | grep -v grep | awk '{print $2}'")
      pids |= collect_stale_pids(node, "ps auxww | grep vespa-fbench | grep -v grep | awk '{print $2}'")
      pids |= collect_stale_pids(node, "ps auxww | grep vespa-visit | grep -v grep | awk '{print $2}'")
      badpids |= collect_stale_pids(node, "ps auxww | grep ^#{user} | grep -i vespa- | grep -v grep | awk '{print $2}'")
      badpids |= collect_stale_pids(node, "ps auxww | grep ^#{user} | grep vespa-config-sentinel | grep -v grep | awk '{print $2}'")
      badpids |= collect_stale_pids(node, "ps auxww | grep ^#{user} | grep vespa-logd | grep -v grep | awk '{print $2}'")
      badpids |= collect_stale_pids(node, "ps auxww | grep vespa-runserver | grep -v grep | awk '{print $2}'")
      badpids |= collect_stale_pids(node, "ps auxww | grep java.*com.yahoo.vespa.http.client | grep -v grep | awk '{print $2}'")

      pids |= badpids

      if pids.size > 0
        @testcase.output("Found #{pids.size} stale processes, " +
               "killing: #{pids.join(" ")}, #{pids.inspect}")
        execute(node, "kill #{pids.join(" ")}")
        sleep 2
        execute(node, "kill -9 #{pids.join(" ")}")
      end
    end
  end

  def remove_model_plugins(nodes)
    nodes.each do |node|
      execute(node, "rm -rf #{Environment.instance.vespa_home}/conf/configserver-app/config-models/*")
    end
  end

  private

  def collect_stale_pids(node, cmd)
    pids = execute(node, cmd)
    begin
      ret = []
      pids.split("\n").collect do |p|
        if p =~ /^\d+$/
          ret << p.to_i
        end
      end
      ret
    rescue
      @testcase.output "Unable to parse pid list: #{pids}"
      []
    end
  end

  def execute(node, cmd)
    node.execute(cmd, :exceptiononfailure => false)
  end
end
