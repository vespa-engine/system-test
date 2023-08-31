# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'nodetypes/clusterstate'
require 'net/http'
require 'distributionstates'

class ContentClusterController < VespaNode
  def initialize(*args)
    super(*args)
    @statusport = @ports[0]
  end

  # This function is broken in that it returns invalid values if non-master
  # cluster controller is queried.
  def get_cluster_state(cluster)
    begin
      state = get_status_page("/clustercontroller-status/v1/" + cluster + "/clusterstate")
      return StorageClusterState.new(testcase, state)
    rescue Exception => e
      testcase.output("Failed to get cluster state " + e.to_s)
      return nil
    end
  end

  def get_reindexing_json
    get_json_over_http("/reindexing/v1/status", @statusport)
  end

  def get_distribution_states(cluster)
    json = get_json_over_http("/cluster/v2/" + cluster, @statusport)
    if json.nil?
      return nil
    end
    distribution_states = json['distribution-states']
    if distribution_states.nil?
      testcase.output("Failed to get distribution states: " + json.to_s)
      return nil
    end
    return DistributionStates.new(testcase, distribution_states)
  end

  def get_status_page(page = "/")
    10.times { |i|
      begin
        return https_get('localhost', @statusport, page).body
      rescue Exception => e
        if (i > 8)
          raise e
        else
          sleep 0.5
        end
      end
    }
  end

  def is_master(clustername)
    begin
      response, data = http_request("/cluster/v2/#{clustername}")
      if (response.code.to_i == 200)
        return true, ''
      else
        return false, "#{response.code} #{response.message}"
      end
    rescue Exception => e
      return false, e.to_s
    end
  end

  def http_request(page = "")
    response = https_get('localhost', @statusport, page)
    return response, response.body
  end

  def set_node_state(cluster, nodetype, index, state, condition=nil)
    state_map = {
      's:u' => 'up',
      's:d' => 'down',
      's:m' => 'maintenance',
      's:r' => 'retired'
    }
    rest_state = state_map[state]
    raise "Could not map state '#{state}' to a REST API state enum" if rest_state.nil?

    uri = URI("http://localhost:#{@statusport}/cluster/v2/#{cluster}/#{nodetype}/#{index}")
    testcase.output(uri.to_s)

    res = with_https_connection(hostname, @statusport, "/cluster/v2/#{cluster}/#{nodetype}/#{index}") do |conn, uri|
      put_req = Net::HTTP::Put.new(uri, { 'Content-Type' => 'application/json'})
      args = { 'state' => { 'user' => { 'state' => rest_state, 'reason' => 'Set by system test framework' } } }
      if condition
        args['condition'] = condition
      end
      put_req.body = args.to_json
      conn.request(put_req)
    end

    if res.code.to_i != 200
      raise "Failed to set node state to '#{rest_state}' (HTTP #{res.code}): #{res.body}"
    end

    json_body = JSON.parse(res.body)
    if json_body['wasModified'] != true
      raise "Cluster controller refused to set node state to '#{rest_state}'. Reason: #{json_body['reason']}"
    end
  end

  def wait_for_stable_system(cluster)
    system = nil
    lastsystem = nil
    retries = 1500
    if testcase.valgrind
      retries = retries * 5
      testcase.output("using #{retries} retries with valgrind")
    elsif testcase.has_active_sanitizers
      retries = retries * 5
      testcase.output("using #{retries} retries with sanitizers")
    else
      testcase.output("using #{retries} retries, no valgrind")
    end

    system = get_cluster_state(cluster)

    # Should also check for cluster:d state, but removing for now as we can't configure when to
    # be down yet
    while (!lastsystem || !system || !(system == lastsystem) || system.initializing)
      retries = retries - 1
      testcase.output("retries: #{retries}")
      if retries <= 0
        dumpJStack
        raise "Timeout while waiting for stable system in fleetcontroller."
      end
      sleep 0.5
      lastsystem = system

      system = get_cluster_state(cluster)
      testcase.output(system.to_s)
    end
    testcase.output("System is stable with state " + system.to_s + "\n")
  end

  def wait_for_matching_distribution_states(cluster)
    retries = 1500
    distribution_states = get_distribution_states(cluster)
    while !distribution_states.nil? && !distribution_states.matching_states
      retries = retries - 1
      testcase.output("wait_for_matching_distribution_states: retries=#{retries}")
      if retries <= 0
        raise "Timeout while waiting for matching distribution states."
      end
      sleep 0.5
      distribution_states = get_distribution_states(cluster)
    end
    return distribution_states
  end


  def do(command, exceptiononfailure = true)
    res = execute(command + " --port #{ports[0]}", :exceptiononfailure => exceptiononfailure)
    arr = res.split("\n")
    arr.shift() # Remove "Connecting to fleetctrl" line
    out = arr.join("\n")
    return out
  end

end
