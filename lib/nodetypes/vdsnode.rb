# Copyright Vespa.ai. All rights reserved.

require 'environment'

class VDSNode < VespaNode
  attr_reader :storagecluster

  def initialize(*args)
    super(*args)
    @statusport = @ports[2]
    @status_conn = nil
  end

  def set_cluster(cluster)
    @storagecluster = cluster
  end

  def is_stress_test?
    return !testcase.cmd_args[:stress_test].nil?
  end

  def get_status(page)
    @status_conn = @https_client.create_client('localhost', @statusport) if ! @status_conn
    @status_conn.get(page)
  end

  def get_status_page(page = "/")
    data = nil
    max_fetch_time = (is_stress_test? or testcase.valgrind) ? 300 : 20
    deadline = Time.now + max_fetch_time
    while Time.now < deadline
      begin
        started = Time.now
        response = get_status(page)
        data = response.body
        break if (response.code.to_i == 200)
        @testcase.output("Got response code #{response.code} when getting status page")
      rescue Exception => e
        @testcase.output("Used #{Time.now - started} seconds to NOT get status page: #{e.to_s}")
      end
      sleep 1
    end
    return data
  end

  def get_system_state
    data = get_status_page("/systemstate")
    if data =~ Regexp.new('Current system state.*<code>(.*)<\/code>.*Current node state', Regexp::MULTILINE) then
      return $1
    end
    raise "Failed to find system state from status page: >>#{data}<<"
  end

  def get_cluster_state_version
    cluster_state = StorageClusterState.new(@test_case, get_system_state)
    return cluster_state.version
  end

  def get_metrics_matching(regex, updateall=false)
    url = "/metrics?interval=-1&format=text&consumer=status&verbosity=2&pattern=#{regex}"
    if updateall then
        url += "&callsnapshothooks=1"
    end
    data = get_status_page(url)
    map = {}
    data.each_line { |line|
      elems = line.split(" ")
      name = elems.shift
      entry = {}
      elems.each { |elem|
        if elem =~ Regexp.new('([^=]+)=(\d+)$')
          entry[$1] = $2.to_i
        elsif elem =~ Regexp.new('([^=]+)=(\d+\.\d+(?:e\+\d+))$')
          entry[$1] = $2.to_f
        elsif elem =~ Regexp.new('([^=]+)=(.*)')
          entry[$1] = $2
        end
      }
      map[name] = entry
    }
    return map
  end

  def get_metric(metric, updateall=false)
    metrics = get_metrics_matching(metric, updateall)
    return metrics[metric]
  end

  # Use only if no fleetcontroller is available
  def set_system_state(state)
    if (servicetype == "storagenode")
      execute("vdsclient --target storage/cluster.#{cluster}/storage/#{index} setsystemstate \"" + state + "\"", :exceptiononfailure => false)
    else
      execute("vdsclient --target storage/cluster.#{cluster}/distributor/#{index} setsystemstate \"" + state + "\"", :exceptiononfailure => false)
    end
  end

  def start_visit_target()
    `vespa-visit-target -s storage/cluster.#{cluster}/visittarget/#{index} -i > #{Environment.instance.vespa_home}/tmp/visittarget.#{index} &`
  end

  def stop_visit_target()
    @node_server.kill_process("VdsVisitTarget")
  end

  def clean()
    stop_visit_target
    execute("rm -f #{Environment.instance.vespa_home}/tmp/visittarget.#{index}")
  end

  def stat(id, include_owner: true)
    statinfo = execute("vespa-stat --route #{cluster} --document #{id}")

    retval = {}
    deleted = "OK"
    node = "0"
    size = "0"
    timestamp = 0
    owner = 0

    statinfo.each_line { | line |
      if line =~ /\[distributor:(\d+)\]/
        owner = $~[1]
      end

      if line =~ Regexp.new('Bucket information from node ([0-9]*):')
        node = $1
      end

      if line =~ Regexp.new('\(remove\)')
        deleted = "DELETED"
      end

      if line =~ Regexp.new('size: ([0-9]+)')
        size = $1
      end

      if line =~ Regexp.new('Timestamp: ([0-9]+)')
        ts = $1.to_i
      end

      if line =~ Regexp.new('Timestamp') && (!retval[node] || retval[node]["timestamp"] < ts)
        retval[node] = { 'status' => deleted, 'size' => size.to_i, 'timestamp' => ts.to_i }
        if include_owner
          retval[node]['owner'] = (node == owner)
        end
        timestamp = ts
      end
    }

    return retval
  end

  def stop(wait_timeout = 120, wait_for_current_state_down = true, force = false)
    @testcase.output "Stopping node #{@index}"
    super(force)
    #VespaNode.instance_method(:stop).bind(self).call()
    if (wait_for_current_state_down)
      @testcase.output "Waiting for #{servicetype}.#{index} to be down in cluster state"
      @storagecluster.wait_for_current_node_state(@servicetype, @index.to_i, 'sdm', wait_timeout)
    end
  end

  def wait_for_current_node_state(wantednodestate, timeout=120)
    @storagecluster.wait_for_current_node_state(@servicetype, @index.to_i, wantednodestate, timeout)
  end

  def wait_for_current_node_capacity(wantednodecapacity, timeout=120)
    @storagecluster.wait_for_current_node_capacity(@servicetype, @index.to_i, wantednodecapacity, timeout)
  end

  def wait_for_current_node_message(wantednodemessage, timeout=120)
    @storagecluster.wait_for_current_node_message(@servicetype, @index.to_i, wantednodemessage, timeout)
  end

end
