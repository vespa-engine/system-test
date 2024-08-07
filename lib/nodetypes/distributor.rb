# Copyright Vespa.ai. All rights reserved.

require 'environment'

class Distributor < VDSNode

  def initialize(*args)
    super(*args)
    @remember_last_in_sync_db_state = false
    @last_in_sync_db_state = nil
  end

  def is_synced?
    state = get_sync_state
    return state == nil
  end

  def get_sync_state
    result = []
    statuspage = get_status_page("/distributor?page=buckets")
    if !has_expected_bucket_db_prologue(statuspage)
      testcase.output('NOTE: bucket DB status page did not have expected format, retrying...')
      return result.push(statuspage)
    end

    count = 0
    statuspage.each_line { |line|
      if (line =~ /<b>BucketId/)
        count = count + 1
      end
    }
    if count == 0
      not_ready = get_ideal_replicas_not_ready()
      count = not_ready.size
      result.push(not_ready) if count > 0
    else
      result.push(statuspage)
    end

    @lastidealstatus = count
    if @remember_last_in_sync_db_state and count == 0
      @last_in_sync_db_state = statuspage
    end

    return nil if @lastidealstatus == 0 
    return result
  end

  # Count the number of bucket replicas that _should_ (eventually) be indexed and made
  # searchable according to the ideal state, but where this currently is not the case.
  # This works as an implicit barrier to wait for search nodes to asynchronously complete
  # background bucket moving and search node -> distributor bucket info change notifications.
  #
  # This only works reliably as a barrier for non-grouped clusters, as this code does
  # not have enough knowledge of the group topology and ideal state to make an informed
  # decision on what _other_ replicas than the first one should be ready.
  #
  # Should only be called on a distributor that has finished its regular ideal state
  # operations.
  def count_ideal_replicas_not_ready
    get_ideal_replicas_not_ready().size
  end

  def get_ideal_replicas_not_ready
    non_ready = []
    each_database_bucket do |space, bucket_id, state, raw_state|
      # Output is in ideal state order, so expect the 1st one to always be ready.
      # This should generalize to always be true for indexed, store-only, flat and grouped setups.
      # We'd ideally check the active-flag as well, but clusters without indexed docs will
      # not activate any replicas.
      non_ready.push([bucket_id, state]) if not state[0].ready
    end
    non_ready
  end

  def remember_last_in_sync_db_state
    @remember_last_in_sync_db_state = true
  end

  def last_in_sync_db_state
    @last_in_sync_db_state
  end

  def has_expected_bucket_db_prologue(statuspage)
    statuspage.include? '<h2>default' # FIXME extreeemely format specific
  end

  def wait_until_synced(timeout=300)
    timeout *= 5 if @testcase.valgrind
    testcase.output("Waiting for distributor #{index} to be in sync. Timeout is #{timeout} seconds.")
    progressTimeInc = 5;
    nextProgressTime = Time.now + progressTimeInc
    endTime = Time.now + timeout
    state = nil
    while (endTime >= Time.now)
      begin
        state = get_sync_state
        if state == nil
          return true
        end
      rescue Errno::ECONNREFUSED
        # Do nothing
      end
      if (Time.now >= nextProgressTime)
        nextProgressTime += progressTimeInc
        testcase.output("not_ready_count = #{@lastidealstatus} : state = #{state.to_s}")
      end
      sleep 0.1
    end
    raise "Distributor did not get in sync within timeout of #{timeout} seconds: #{@lastidealstatus}  : state = #{state[0].to_s}"
  end

  def with_status_page(relative_url)
    raise 'Must specify block' if not block_given?
    # Loop until global timeout; no timeout specific to this method.
    while true
      statuspage = nil
      begin
        statuspage = get_status_page(relative_url)
      rescue Exception => e
        testcase.output("Got exception when fetching status page '#{relative_url}' from " +
                        "distributor #{index}, assuming node is down")
      end
      return if statuspage.nil?
      return if yield(statuspage)
      sleep 1
    end    
  end

  def wait_until_all_pending_bucket_info_requests_done
    with_status_page('/bucketdb') do |content|
      xml = REXML::Document.new(content)
      return true if xml.nil? || xml.root.nil?
      xml.root.each_element('/status/bucketdb/systemstate_pending') do |node|
        testcase.output("Waiting for pending cluster state to clear on distributor #{index}")
        return false
      end
      xml.root.each_element('/status/bucketdb/single_bucket_requests/storagenode') do |node|
        testcase.output("Waiting for single bucket requests to complete on distributor #{index}")
        return false
      end
      xml.root.each_element('/status/bucketdb/delayed_single_bucket_requests/storagenode') do |node|
        testcase.output("Waiting for delayed single bucket requests to complete on distributor #{index}")
        return false
      end
      true
    end
  end

  def wait_until_external_load_drained
    with_status_page('/distributor?page=pending') do |content|
      xml = REXML::Document.new(content)
      return true if xml.nil? || xml.root.nil? # broken page
      pending_ops = xml.root.elements['pending'].attributes['externalload']
      if pending_ops.nil?
        raise "No pending external load attribute found in XML"
      end
      is_done = pending_ops.to_i == 0
      if !is_done
        testcase.output("Waiting for #{pending_ops} pending external load " +
                        "operations to drain on distributor #{index}...")
      end
      is_done
    end
  end

  def get_numdoc_stored
    metric = get_metric("vds.distributor.docsstored", true)
    if metric != nil then
        return metric["last"]
    end
    return 0
  end

  # Parse and return an array of DistributorBucketCopy
  def parse_distributor_bucket_idealstate(nodegroup)
    nodes = nodegroup.split(", ")
    ret = []
    nodes.each do |node_desc|
      if node_desc == "no nodes"
        # nothing to add
      elsif node_desc =~ /node\(idx=(\d+),crc=(0x[a-f0-9]+),docs=(\d+)\/(\d+),bytes=(\d+)\/(\d+),trusted=(true|false),active=(true|false)(?:,ready=(true|false))?\)/
        idx = $~[1].to_i
        crc = $~[2].to_i(16)
        docs = $~[3].to_i
        metacount = $~[4].to_i
        bytes = $~[5].to_i
        usedfilesize = $~[6].to_i
        trusted = ($~[7] == 'true')
        active = ($~[8] == 'true')
        ready = ($~[9] == 'true')
        ret << DistributorBucketCopy.new(idx, crc, docs, metacount, bytes,
                                         usedfilesize, trusted, ready, active)
      elsif is_gc_entry?(node_desc)
        # Casually ignore it, as these are periodic.
      else
        raise "Unknown node idealstate entry: '#{node_desc}'. Failed to parse string '#{nodegroup}'"
      end
    end
    ret
  end

  def is_gc_entry?(entry)
    entry =~ /Needs garbage collection/
  end

  def each_database_bucket
    raise 'No block provided' unless block_given?
    content = get_status_page('/distributor?page=buckets')

    current_space = 'default'
    content.each_line do |line|
      if line =~ /BucketId\(0x([0-9a-f]+)\).*?\[(.*?)\]/
        bucket_id = $~[1]
        raw_state = $~[2]
        parsed_state = parse_distributor_bucket_idealstate(raw_state)
        if parsed_state.empty?
          flunk("Bucket 0x#{bucket_id} is in distributor #{index}'s database, but it " +
                "is empty: #{raw_state}")
        end
        yield(current_space, bucket_id, parsed_state, raw_state)
      elsif line =~ /(default|global) - BucketSpace/
        current_space = $~[1]
      end
    end
  end


end
