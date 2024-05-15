# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "document.rb"
require 'assertions'
require 'bucket_copy'
require 'nodetypes/storageclusterstate.rb'
require 'environment'

# Required since cluster controllers aren't located in the cluster.
class ClusterControllerWrapper
  def initialize(clusterctrl, name)
    @clustercontroller = clusterctrl
    @clustername = name
  end

  def wait_for_stable_system
    @clustercontroller.wait_for_stable_system(@clustername)
  end

  def set_node_state(nodetype, index, state, condition=nil)
    @clustercontroller.set_node_state(@clustername, nodetype, index, state, condition)
  end

  def get_cluster_state
    @clustercontroller.get_cluster_state(@clustername)
  end

  def get_distribution_states
    @clustercontroller.get_distribution_states(@clustername)
  end

  def wait_for_matching_distribution_states
    @clustercontroller.wait_for_matching_distribution_states(@clustername)
  end

  def restart
    @clustercontroller.restart
  end

end

class Storage
  include Assertions

  attr_accessor :distributor, :feeder, :fleetcontroller, :storage, :stress, :clustername
  attr_reader :bucket_crosscheck_params

  def initialize(testcase, clustername, vespa)
    @testcase = testcase
    @vespa = vespa
    @fleetcontroller = {}
    @distributor = {}
    @storage = {}
    @feeder = {}
    @stress = {}
    @clustername = clustername
    @bucket_crosscheck_params = {}
  end

  def clean
    @distributor.each { | key, distrib |
      distrib.clean
    }

    @storage.each { | key, stor |
      stor.clean
    }
  end

  def Storage.error_code(message)
    if (message.detail.index(':')) then
      return message.detail[0, message.detail.index(':') - 1]
    else
      return message.detail
    end
  end

  def Storage.error_detail(message)
    if (message.detail.index(':')) then
      return message.detail[message.detail.index(':')  + 1, message.detail.length - message.detail.index(':')]
    else
      return message.detail
    end
  end

  def get_master_fleet_controller(timeout = 120)
    if (@fleetcontroller && @fleetcontroller[@fleetcontroller.keys().sort().first()]) 
      @testcase.output("Returning fleet controller")
      return @fleetcontroller[@fleetcontroller.keys().sort().first()]
    end
    return ClusterControllerWrapper.new(get_master_cluster_controller(timeout), @clustername)
  end

  def get_master_cluster_controller(timeout = 120)
    wait_time_in_between_tries = 0.1
    iterations = [(timeout / wait_time_in_between_tries).to_i, 1].max
    iterations.times do |iteration|
      ccindexes = @vespa.clustercontrollers.keys().sort()
      ccindexes.each do |index|
        result, status = @vespa.clustercontrollers[index].is_master(@clustername)
        if (result)
          if (iteration > 0 || index.to_i != 0)
            @testcase.output("Cluster controller #{index} is now master.")
          end
          return @vespa.clustercontrollers[index]
        end
        if (iteration + 1 == iterations)
            @testcase.output("Failed to talk to cluster controller #{index}: #{status}")
        end
      end
      sleep(wait_time_in_between_tries)
    end
    ccindexes = @vespa.clustercontrollers.keys().sort()
    ccindexes.each do |index|
      @vespa.clustercontrollers[index].dumpJStack
    end
    raise "No cluster controller master found within timeout"
  end

  def adjust_timeout(timeout)
    if @testcase.valgrind
      timeout *= 5
      @testcase.output("using timeout #{timeout} with valgrind")
    elsif @testcase.has_active_sanitizers
      timeout *= 5
      @testcase.output("using timeout #{timeout} with sanitizers")
    else
      @testcase.output("using timeout #{timeout}, no valgrind")
    end
    timeout
  end

  def wait_for_cluster_state_propagate(clusterstate, timeout = 120, check_states = "ui")
    @testcase.output("Waiting for all nodes in states #{check_states} to have " +
                     "cluster state version of at least #{clusterstate.version}. " +
                     "Timeout is #{timeout} seconds.")
    endtime = Time.now + timeout
    nodes = Array.new
    nodes += clusterstate.storage_nodes
    nodes += clusterstate.distributor_nodes
    version_fetch_time = {}
    nodes.each do |node|
      if (node.state =~ /^[#{check_states}]$/)
        nodearr = (node.type == 'storage' ? @storage : @distributor)
        nodearr.each do |index, vdsnode|
          #@testcase.output("Checking #{node.type}.#{index}")
          if (index.to_i == node.index)
            max_fetch_time = 0
            lastSeenVersion = 0
            while true
              time_started = Time.now
              currVersion = vdsnode.get_cluster_state_version
              max_fetch_time = [Time.now - time_started, max_fetch_time].max
              if (currVersion >= clusterstate.version)
                @testcase.output("Cluster state version in #{node.type}.#{index} is now #{currVersion}")
                break;
              end
              if (endtime < Time.now)
                statuspage = vdsnode.get_status_page("/systemstate")
                @testcase.output("Status page to get cluster state: '#{statuspage}'")
                clusterstate = vdsnode.get_system_state
                @testcase.output("Cluster state parsed from it: '#{clusterstate}'")
                raise "Node #{node.type}.#{index} still has version #{currVersion} after timeout of #{timeout} seconds."
              end
              if currVersion > lastSeenVersion
                @testcase.output("Waiting for #{node.type}.#{index} to get version >= #{clusterstate.version}. Now has #{currVersion}")
                lastSeenVersion = currVersion
              end
              sleep 0.1
            end
            node_key = "#{node.type}.#{node.index}"
            version_fetch_time[node_key] = max_fetch_time
          end
        end
      else
        @testcase.output("Skipping #{node.type}.#{node.index} as state is #{node.state}")
      end
    end
    @testcase.output("All nodes in states #{check_states} now have cluster state version #{clusterstate.version} or newer")
    # @testcase.output('State version fetch times: ' + version_fetch_time.map{|n,t| sprintf('%s -> %.3fs', n, t)}.join(', '))
  end

  def wait_until_cluster_up(timeout = 120)
    wait_until_cluster_state('u', timeout)
  end
  def wait_until_cluster_down(timeout = 120)
    wait_until_cluster_state('d', timeout)
  end

  def wait_for_state_condition(timeout = 120)
    timeout = adjust_timeout(timeout)
    progressReportInterval = 5
    nextProgressReport = Time.now + progressReportInterval
    endtime = Time.now + timeout

    while (Time.now < endtime)
      state = get_cluster_state

      if (!state.nil?)
        if yield state
          begin
            wait_for_cluster_state_propagate(state, endtime - Time.now)
          rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
            @testcase.output("Caught connection exception '#{e}' while " +
                             "waiting for cluster state propagation; " +
                             "assuming this is because node went down before " +
                             "this was visible in cluster state. Retrying...")
            redo
          end
          return true
        end
      end
      if (Time.now >= nextProgressReport)
        nextProgressReport += progressReportInterval
        @testcase.output("Current state is '#{state.nil? ? '(not reported)' : state.statestr}'")
      end
      sleep 0.1
    end
    return false
  end

  def wait_until_cluster_state(wantedstate, timeout = 120)
    @testcase.output("Waiting for global cluster state to be " + wantedstate)
    cstate = nil;
    ok = wait_for_state_condition(timeout) { |state|
      cstate = state
      state.get_global_state == wantedstate
    }
    if (!ok)
      assert(false,
             "Cluster didn't get to state " + wantedstate +
             " within timeout of " + timeout.to_s +
             " seconds. Current state is '" + cstate.statestr + "'.")
    end
  end

  def wait_for_distribution_bits(wantedbits, timeout=120)
    @testcase.output("Waiting for cluster state to report " +
                     wantedbits.to_s + " bits.")

    ok = wait_for_state_condition(timeout) { |state|
      state && state.bits == wantedbits
    }
    if (!ok)
      assert(false,
             "Did not get " + wantedbits.to_s + " bits" +
             " within timeout of " + timeout.to_s +
             " seconds.")
    end
  end

  def wait_for_node_count(type, wantedcount, check_states, timeout = 120)
    if (type == 'storagenode') # Allow taking type from servicetype
      type = 'storage'
    end
    @testcase.output("Waiting for " + wantedcount.to_s + " nodes of type " +
                     type + " in states " + check_states + ".")
    cstate = nil;
    ok = wait_for_state_condition(timeout) { |state|
      cstate = state
      nodes = Array.new
      if (type == 'storage')
        nodes = state.storage_nodes
      end
      if (type == 'distributor')
        nodes = state.distributor_nodes
      end
      nodecount = 0;
      nodes.each do |node|
        if (node.state =~ /^[#{check_states}]$/)
          nodecount = nodecount + 1
        end
      end
      nodecount == wantedcount
    }
    if (!ok)
      assert(false,
             "Did not get " + wantedcount.to_s + " nodes of type " + type +
             " in states " + check_states +
             " within timeout of " + timeout.to_s +
             " seconds.")
    end
  end

  def wait_for_current_node_state(type, index, wantednodestate, timeout = 120)
    if (type == 'storagenode') # Allow taking type from servicetype
      type = 'storage'
    end
    @testcase.output("Waiting for node state of " + type + "." + index.to_s +
                     " to be one of [" + wantednodestate + "].")
    ok = wait_for_state_condition(timeout) { |state|
      nodestate = state.get_node_state(type, index).state
      if (state.get_global_state == 'd')
        nodestate = 'd'
      end
      nodestate =~ /^[#{wantednodestate}]$/
    }
    if (!ok)
      assert(false,
             "Node " + type + "." + index.to_s + " did not reach state " +
             wantednodestate + " within timeout of " + timeout.to_s +
             " seconds.")
    end
  end

  def wait_for_current_node_capacity(type, index, wantedcapacity, timeout = 120)
    if (type == 'storagenode') # Allow taking type from servicetype
      type = 'storage'
    end
    @testcase.output("Waiting for node capacity of " + type + "." +
                     index.to_s + " to be " + wantedcapacity.to_s + ".")
    ok = wait_for_state_condition(timeout) { |state|
      state && state.get_node_state(type, index).capacity == wantedcapacity
    }
    if (!ok)
      assert(false,
             "Node " + type + "." + index.to_s + " did not get capacity " +
             wantedcapacity.to_s + " within timeout of " + timeout.to_s +
             " seconds.")
    end
  end

  def wait_for_current_node_message(type, index, wantednodemessage, timeout = 120)
    if (type == 'storagenode') # Allow taking type from servicetype
      type = 'storage'
    end
    @testcase.output("Waiting for node message of " + type + "." + index.to_s +
                     " to be '" + wantednodemessage + "'.")
    ok = wait_for_state_condition(timeout) { |state|
      state && state.get_node_state(type, index).message == wantednodemessage
    }
    if (!ok)
      assert(false,
             "Node " + type + "." + index.to_s + " did not get message " +
             wantednodemessage + " within timeout of " + timeout.to_s +
             " seconds.")
    end
  end

  def wait_until_state_is(state, timeout = 120)
    endtime = Time.now + adjust_timeout(timeout)
    while (Time.now < endtime)
      system = get_master_fleet_controller().get_system_state
      clusterState = StorageClusterState.new(@testcase, system)

      @testcase.output("State before stripping is '" + system.split(/\s+/).join(" ") + "'")
      array = Array.new
      diskcount = ''
      system.split(/\s+/).each do |elem|
        if (elem =~ /^version:/) then
        elsif (elem =~ /^bits:/) then
        elsif (elem =~ /^\.\d+\.d\.\d+\.m:/) then
        elsif (elem =~ /^\.\d+\.m:/) then
#        elsif (elem =~ /^\.\d+\.t:/) then
        elsif (elem =~ /^\.\d+\.d:/) then
          diskcount = elem
        elsif (elem =~ /^\.\d+\.d\.\d+\.s:/)
          array.push(diskcount)
          array.push(elem)
          diskcount = ''
        else
          array.push(elem)
        end
      end

      system = array.join(" ")

      @testcase.output("Wanted:   '" + state.split(/\s+/).join(" ") + "'")
      @testcase.output("State is: '" + system.split(/\s+/).join(" ") + "'")

      # Sorting states can produce wrong results. We will match a distributor
      # being down if checking for storage node being down if they have same
      # index. But for testing it is fairly sufficient
      if (sortstate(state) == sortstate(system)) then
        @testcase.output("    State is equal")
        wait_for_cluster_state_propagate(clusterState, endtime - Time.now)
        return true;
      else
        @testcase.output("    State differs")
      end

      @testcase.output("")

      sleep 0.1
    end

    assert(false, "State did not become '" + state + "' within timeout of " +
           timeout.to_s  + " seconds")
  end

  def wait_until_all_services_up(timeout=180)
    @testcase.output("Waiting for fleetcontroller...")
    get_master_fleet_controller(timeout).wait_for_stable_system

    @testcase.output("Waiting until all storage nodes and distributors have come up in cluster '#{@clustername}'...")
    wait_for_node_count('storage', @storage.size, 'u', timeout)
    wait_for_node_count('distributor', @distributor.size, 'u', timeout)

    wait_for_cluster_state_propagate(get_cluster_state, timeout)
  end

  def wait_until_state_contains(state, timeout = 120)
    endtime = Time.now + adjust_timeout(timeout)
    while (Time.now < endtime)
      system = get_master_fleet_controller().get_system_state
      clusterState = StorageClusterState.new(@testcase, system)

      @testcase.output("Wanted:   '" + state + '"')
      @testcase.output("State is: '" + system + '"')

      a = state.split
      b = system.split

      if (a-b).size == 0
        @testcase.output("    State is contained")
        wait_for_cluster_state_propagate(clusterState, endtime - Time.now)
        return true
      end
      @testcase.output("    State is not contained")
      @testcase.output("")

      sleep 0.1
    end
    assert(false, "State did not contain '" + state + "' within timeout of " +
           timeout.to_s  + " seconds")
  end

  def wait_until_state_not_contains(state, timeout = 120)
    endtime = Time.now + adjust_timeout(timeout)
    while (Time.now < endtime)
      system = get_master_fleet_controller().get_system_state
      clusterState = StorageClusterState.new(@testcase, system)

      @testcase.output("Don't want:   '" + state + '"')
      @testcase.output("State is: '" + system + '"')

      a = state.split
      b = system.split

      if (a-b).size == a.size
        @testcase.output("    State is not contained")
        wait_for_cluster_state_propagate(clusterState, endtime - Time.now)
        return true
      end
      @testcase.output("    State is contained")
      @testcase.output("")

      sleep 0.1
    end
    assert(false, "State did still contain '" + state + "' after timeout of " +
           timeout.to_s  + " seconds")
  end

  def wait_until_content_nodes_have_config_generation(gen)
    @testcase.output("Waiting for content cluster nodes to ack config generation #{gen}")
    @storage.each_value { |node|
      node.wait_for_config_generation(gen)
    }
    @distributor.each_value { |node|
      node.wait_for_config_generation(gen)
    }
  end

  def sortstate(str)
    return str.split(/\s+/).sort.join(" ")
  end

  def distributors_ready?(blocklist=[])
    # Don't include blocklisted (presumably down) distributors in testing
    @distributor.each do | key, distrib |
      next if blocklist.include? key
      return false if not distrib.is_synced?
    end
    true
  end

  def compare_bucket_states(a, b)
    return a.crc == b.crc && a.docs == b.docs
  end

  def is_bucket_info_valid?(c)
    return c.docs > 0 || c.bytes == 0
  end

  class BucketStateFailureListener
    def notify_failure(bucket, distributor_idx, msg)
      raise "Implement in subclass"
    end
  end

  def node_is_up?(state, type, i)
    if type == :distributor
      return state !~ Regexp.new("distributor:\d+.* \\.#{i}.s:[^u] .*storage:")
    elsif type == :storagenode
      return state !~ Regexp.new("storage:.* \\.#{i}.s:[^u]")
    else
      raise "Unknown node type: #{type}"
    end
  end

  def gather_storagenode_bucket_databases(cluster_state)
    storage_state = { 'default' => {}, 'global' => {} }
    @storage.each do |i, stor|
      node = @vespa.content_node(@clustername, i)
      state = node.get_sentinel_state
      if state != "RUNNING"
        @testcase.output("Not checking storage node #{i} as its state " +
                         "is #{state}")
        next
      elsif !cluster_state.isup("storage", i.to_i)
        @testcase.output("Not checking storagenode #{i} as it is not " +
                         "marked as being up in the current cluster state")
        next
      end
      @testcase.output("Fetching bucket database on storagenode #{i}")
      db = stor.get_buckets
      idx = i.to_i
      db.each do |space, buckets|
        storage_state[space][idx] = buckets
      end
    end
    storage_state
  end

  def gather_merged_view_of_all_distributor_bucket_databases(cluster_state)
    dist_buckets = { 'default' => {}, 'global' => {} }
    @distributor.each do |i, dist|
      if dist.get_state != "RUNNING"
        @testcase.output("Not checking distributor #{i} as its state " +
                         "is #{dist.get_state}")
        next
      elsif !cluster_state.isup("distributor", i.to_i)
        @testcase.output("Not checking distributor #{i} as it is not " +
                         "marked as being up in the current cluster state")
        next
      end
      checked_buckets_dist = 0
      @testcase.output("Fetching bucket database on distributor #{i}")

      dist.each_database_bucket do |space, bucket_id, parsed_state, raw_state|
        if dist_buckets[space].has_key? bucket_id
          flunk("Bucket 0x#{bucket_id} is in distributor #{i}'s database, but can " +
                "already be found on distributor #{dist_buckets[space][bucket_id][0]}")
        end
        dist_buckets[space][bucket_id] = [i.to_i, parsed_state, raw_state]
      end
    end
    dist_buckets
  end

  def dump_bucket_information(bucket)
    @vespa.adminserver.execute("vespa-stat --bucket 0x#{bucket} --route #{@clustername}",
                               :exceptiononfailure => false)
  end

  ValidationStats = Struct.new(:checked_buckets_total, :dist_docs_total)

  def validate_bucket_space(space, dist_buckets, storage_state, params)
    checked_buckets_total = 0
    dist_docs_total = 0
    dist_buckets.each_pair do |bucket, state_wrapper|
      begin
        i = state_wrapper[0] # dist idx
        state = state_wrapper[1] # DistributorBucketCopy
        raw_distributor_state = state_wrapper[2]
        if params[:check_redundancy] and state.size != params[:check_redundancy]
          flunk("Bucket 0x#{bucket} on distributor #{i} does not have " +
                "the correct number of copies (#{state.size} != " +
                "#{params[:check_redundancy]}): #{raw_distributor_state}")
        end
        active_copy = -1
        for j in 0...state.size
          entry = state[j]
          if j > 0 and !compare_bucket_states(entry, state[0])
            flunk("Bucket 0x#{bucket} on distributor #{i} has out-of-sync " +
                  "copy: #{raw_distributor_state}")
          end
          if !is_bucket_info_valid? entry
            flunk("Bucket 0x#{bucket} on distributor #{i} has copy " +
                  "with INVALID info: #{raw_distributor_state}")
          end
          if !entry.trusted
            flunk("Bucket 0x#{bucket} on distributor #{i} has " +
                  "non-trusted copy: #{raw_distributor_state}")
          end
          if entry.active
            if active_copy != -1 && @active_check_mode == :single_active_per_bucket
              flunk("Bucket 0x#{bucket} on distributor #{i} has " +
                    "multiple copies marked as active: #{raw_distributor_state}")
            end
            active_copy = j
          end
          # Crosscheck entry with storage node it should be on
          if storage_state[entry.idx].nil?
            flunk("Entry #{j} for bucket 0x#{bucket} on distributor " +
                  "#{i} has storage node index #{entry.idx}, but " +
                  "according to the test that storage node should be down: " +
                  "#{raw_distributor_state}")
          end
          stor_entry = storage_state[entry.idx][bucket]
          if stor_entry.nil?
            flunk("Entry #{j} for bucket 0x#{bucket} on distributor " +
                  "#{i} has node index #{entry.idx}, but the bucket " +
                  "is not in that storage node's database: #{raw_distributor_state}")
          end
          stor_entry.mark_as_seen
          if !compare_bucket_states(stor_entry, entry)
            flunk("Entry #{j} for bucket 0x#{bucket} on distributor #{i} has node index " +
                  "#{entry.idx}, but the bucket on that storage node is not in sync: " +
                  "#{raw_distributor_state} != #{stor_entry}")
          end
          if params[:max_doc_count] and entry.docs > params[:max_doc_count]
            flunk("Doc count for bucket 0x#{bucket} is > maximum of " +
                  "#{params[:max_doc_count]}. Distributor: #{raw_distributor_state}, " +
                  "storage: #{stor_entry}")
          end
        end
        if params[:check_active]
          if !state.empty? and active_copy == -1
            flunk("Bucket 0x#{bucket} on distributor #{i} has no active copies: " +
                  "#{raw_distributor_state}")
          end
          for j in 0...state.size
            entry = state[j]
            stor_entry = storage_state[entry.idx][bucket]
            if entry.active
              if !stor_entry.active
                flunk("Bucket 0x#{bucket} is marked as active on distributor " +
                      "#{i}, but the storage bucket db on node #{entry.idx} says otherwise. " +
                      "Distributor: #{raw_distributor_state}, storage: #{stor_entry}")
              end
            elsif stor_entry.active
              flunk("Bucket 0x#{bucket} on storage node #{entry.idx} should not " +
                    "be marked as active according to distributor #{i}. " +
                    "Distributor: #{raw_distributor_state}, storage: #{stor_entry}")
            end
          end
        end
        dist_docs_total += state[0].docs # all copies in sync so index doesn't matter
      rescue Exception => e
        @testcase.output("Cluster cross-check FAILED: found inconsistency " +
                         "for bucket 0x#{bucket} on distributor #{i}: #{e}")
        dump_bucket_information(bucket)
        if params[:failure_listener]
          params[:failure_listener].notify_failure(bucket, i, e.to_s)
        end
        if params[:dump_distributor_db_states_on_failure]
          @testcase.output("Last in-sync bucket DB state on distributor #{i}:")
          @testcase.output(@distributor[i.to_s].last_in_sync_db_state)
        end
        raise
      end
      checked_buckets_total += 1
    end
    ValidationStats.new(checked_buckets_total, dist_docs_total)
  end

  def bucket_spaces
    return ['global', 'default']
  end

  def validate_no_orphaned_replicas_on_content_node(state, node_index)
      state.each_pair do |bid,info|
        if info.orphaned
          dump_bucket_information(bid)
          flunk("Found orphaned bucket copy 0x#{bid} on storage node " +
                "#{node_index}: #{info}. Copy not seen in any distributor's " +
                "bucket database.")
        end
      end
  end

  # Crosscheck that all bucket databases are consistent with each other.
  # Optional parameters:
  #   :max_doc_count => max meta count for a bucket
  def validate_cluster_bucket_state(params={})
    cluster_state = get_cluster_state
    if cluster_state.get_global_state == 'd'
      @testcase.output("Not validating bucket databases since cluster is down")
      return
    end

    storage_state = gather_storagenode_bucket_databases(cluster_state)
    storage_space_buckets = storage_state.map{|space, nodes|
      [space, nodes.map{|idx, buckets| buckets.size}.reduce(0, :+)]
    }.to_h
    storage_buckets_total = storage_space_buckets.map{|space, count| count}.reduce(:+)

    dist_buckets = gather_merged_view_of_all_distributor_bucket_databases(cluster_state)

    # Breakdown case: if we've got 0 buckets on one node type but not the
    # other, it's likely that the status page format has changed. Do an
    # early (hopefully more helpful) exit if that's the case.
    if (dist_buckets['default'].empty? and dist_buckets['global'].empty?) ^ (storage_buckets_total == 0)
      flunk("Parsed #{dist_buckets['default'].size} buckets on the distributors " +
            "but #{storage_buckets_total} buckets on the storage nodes. " +
            "Assuming status page format has changed or something's broken.")
    end

    @testcase.output("Found #{dist_buckets['default'].size} default/#{dist_buckets['global'].size} " +
                     "global buckets on the distributors " +
                     "and a total of #{storage_space_buckets['default']} default/#{storage_space_buckets['global']} global " +
                     "bucket copies across all storage nodes")

    # Now, process all distributor database entries
    checked_buckets_total = 0
    dist_docs_total = 0
    bucket_spaces.each do |space|
      res = validate_bucket_space(space, dist_buckets[space], storage_state[space], params)
      checked_buckets_total += res.checked_buckets_total
      dist_docs_total += res.dist_docs_total
    end

    @storage.each do |node_index, stor|
      bucket_spaces.each do |space|
        state = storage_state[space][node_index.to_i]
        next if state.nil?
        validate_no_orphaned_replicas_on_content_node(state, node_index.to_i)
      end
    end
    @testcase.output("Cross-checked #{checked_buckets_total} buckets in total. " +
                     "Distributors claim to have #{dist_docs_total} documents in " +
                     "total across all bucket spaces")
  end

  def get_cluster_state
    if (@fleetcontroller && @fleetcontroller[@fleetcontroller.keys().sort().first()]) 
      fleetcontroller_index = @fleetcontroller.keys().sort().first()
      state_string = @fleetcontroller[fleetcontroller_index].get_system_state
      if (state_string == nil)
        return nil
      end
      return StorageClusterState.new(@testcase, state_string)
    end
    return get_master_fleet_controller().get_cluster_state()
  end

  def bucket_activation_disabled_through_config?
    @distributor.find { |key, node|
      config = @testcase.getvespaconfig('vespa.config.content.core.stor-distributormanager', node.config_id)
      return config["disable_bucket_activation"] == true
    }
  end

  def this_cluster_is(search_cluster)
    search_cluster == @clustername
  end

  def has_search_nodes?(cluster)
    not cluster.searchnode.empty?
  end

  def is_a_search_cluster?
    @vespa.search.find { |cluster_name, cluster|
      this_cluster_is(cluster_name) and has_search_nodes?(cluster)
    }
  end

  def should_crosscheck_active?
    is_a_search_cluster? and not bucket_activation_disabled_through_config?
  end

  def set_bucket_crosscheck_params(params={})
    @bucket_crosscheck_params = params
  end

  def wait_until_ready(timeout = 120, blocklist=[])
    @testcase.output("Waiting until storage cluster is ready") 
    # Effectively ignore timeout since they are usually ad-hoc and
    # lead to test instabilities when systest nodes are heavily loaded.
    timeout = @testcase.timeout || timeout
    @testcase.output("Waiting for fleetcontroller...")
    get_master_fleet_controller().wait_for_stable_system
    get_master_fleet_controller().wait_for_matching_distribution_states
    cluster_state = get_cluster_state

    wait_for_cluster_state_propagate(cluster_state, timeout)

    @testcase.output("Waiting for content nodes...")
    online_content_nodes = @storage.select{|k, n| cluster_state.isup('storage', k.to_i)}.
                                    reject{|k, v| blocklist.include? k}
    online_content_nodes.each do |key, node|
      node.wait_until_no_pending_bucket_moves
    end

    crosscheck_buckets_params = {}
    if should_crosscheck_active?
      crosscheck_buckets_params[:check_active] = :single_active_per_bucket
    end
    crosscheck_buckets_params.merge! @bucket_crosscheck_params

    @testcase.output("Waiting for distributors...")
    # Don't include blocklisted (presumably down) distributors in testing
    @distributor.each do | key, distrib |
      next if blocklist.include? key
      distrib.remember_last_in_sync_db_state if crosscheck_buckets_params[:dump_distributor_db_states_on_failure]
      distrib.wait_until_all_pending_bucket_info_requests_done
      distrib.wait_until_synced(timeout)
    end

    @testcase.output("Cross checking buckets (check active states: " +
                     "#{crosscheck_buckets_params[:check_active]})")
    validate_cluster_bucket_state(crosscheck_buckets_params)
    true
  end

  def add_service(remote_serviceobject)
    if not remote_serviceobject
      return
    end
    if remote_serviceobject.servicetype == "fleetcontroller"
      @fleetcontroller[remote_serviceobject.index] = remote_serviceobject
    elsif remote_serviceobject.servicetype == "distributor"
      @distributor[remote_serviceobject.index] = remote_serviceobject
      remote_serviceobject.set_cluster(self)
    elsif remote_serviceobject.servicetype == "storagenode"
      @storage[remote_serviceobject.index] = remote_serviceobject
      remote_serviceobject.set_cluster(self)
    #elsif remote_serviceobject.servicetype == "feeder"
    #  @feeder[remote_serviceobject.index] = remote_serviceobject
    elsif remote_serviceobject.servicetype == "stress"
      @stress[remote_serviceobject.index] = remote_serviceobject
    end
  end

  def to_s
    repr_string = ""
    fleetcontroller.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    distributor.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    storage.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    stress.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    return repr_string.chomp
  end

  def assert_document_count(expectedCount, selection = nil)
    docPattern = "^((user|group|order)?doc|id):.*:.* \\(Last modified at [0-9]+"
    stdOutLog = "#{Environment.instance.vespa_home}/tmp/vespa-visit.stdout.log"
    stdErrLog = "#{Environment.instance.vespa_home}/tmp/vespa-visit.stderr.log"
    cmd = "vespa-visit -i"
    if (selection != nil)
      cmd += " -s '#{selection}'"
    end
    cmd += " >#{stdOutLog} 2>#{stdErrLog}"
    @vespa.adminserver.execute(cmd)
    cmd = "cat #{stdOutLog} | egrep \"#{docPattern}\" | cut -d ' ' -f 1 | sort | uniq | wc -l"
    docCount = @vespa.adminserver.execute(cmd).to_i
    if (docCount == expectedCount)
      return
    end
    failure = "Expected #{expectedCount} documents, but got #{docCount} " +
              "documents. Output:\n"
    if (File.exist?(stdErrLog))
      failure += "STDERR:\n" +
                 @vespa.adminserver.execute("head -n100 #{stdErrLog}")
    end
    if (File.exist?(stdOutLog))
      if (docCount > 100)
        failure += "STDOUT (without document ids):\n"
        cmd = "egrep -v \"#{docPattern}\" #{stdOutLog} | head -n 100"
        failure += @vespa.adminserver.execute(cmd)
      else
        failure += "STDOUT:\n" +
              @vespa.adminserver.execute("cat #{Environment.instance.vespa_home}/tmp/vespa-visit.stdout.log")
      end
    end
    flunk(failure)
  end

  def get_document_count(selection = nil)
    docPattern = "^((user|group|order)?doc|id):.*:.* \\(Last modified at [0-9]+"
    stdOutLog = "#{Environment.instance.vespa_home}/tmp/vespa-visit.stdout.log"
    stdErrLog = "#{Environment.instance.vespa_home}/tmp/vespa-visit.stderr.log"
    cmd = "VESPA_LOG_LEVEL=error,warning vespa-visit -i"
    if (selection != nil)
      cmd += " -s '#{selection}'"
    end
    cmd += " >#{stdOutLog} 2>#{stdErrLog}"
    @vespa.adminserver.execute(cmd)
    cmd = "cat #{stdOutLog} | egrep \"#{docPattern}\" | cut -d ' ' -f 1 | sort | uniq | wc -l"
    docCount = @vespa.adminserver.execute(cmd).to_i
    cmd = "cat #{stdOutLog} #{stdErrLog} 2>/dev/null | wc -l"
    countWithErrors = @vespa.adminserver.execute(cmd).to_i
    if countWithErrors == docCount
      return docCount
    end
    failure = "Tried to get document count, but got non-document output:\n"
    if (@vespa.adminserver.file_exist?(stdErrLog))
      failure += "STDERR:\n" +
                 @vespa.adminserver.execute("head -n100 #{stdErrLog}")
    end
    if (@vespa.adminserver.file_exist?(stdOutLog))
      failure += "STDOUT (without document ids):\n"
      cmd = "egrep -v \"#{docPattern}\" #{stdOutLog} | head -n 100"
      failure += @vespa.adminserver.execute(cmd)
    end
    flunk(failure)
  end

end
