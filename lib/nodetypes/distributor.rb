# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

class Distributor < VDSNode

  def initialize(*args)
    super(*args)
    @remember_last_in_sync_db_state = false
    @last_in_sync_db_state = nil
  end

  def is_synced?
    statuspage = get_status_page("/distributor?page=buckets")
    if !has_expected_bucket_db_prologue(statuspage)
      testcase.output('NOTE: bucket DB status page did not have expected format, retrying...')
      return false
    end

    count = 0
    statuspage.each_line { |line|
      if (line =~ /<b>BucketId/)
        count = count + 1
      end
    }

    @lastidealstatus = count
    if @remember_last_in_sync_db_state and count == 0
      @last_in_sync_db_state = statuspage
    end

    return @lastidealstatus == 0
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
    while (endTime >= Time.now)
      begin
        if is_synced?
          return true
        end
      rescue Errno::ECONNREFUSED
        # Do nothing
      end
      if (Time.now >= nextProgressTime)
        nextProgressTime += progressTimeInc
        testcase.output(@lastidealstatus)
      end
      sleep 0.1
    end
    raise "Distributor did not get in sync within timeout of #{timeout} seconds:\n#{@lastidealstatus}"
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

  def create_dummy_feed(count, size)
    f = File.open("#{Environment.instance.vespa_home}/tmp/feedtmp", "w")
    f.write("<vespafeed>\n");
    count.times { |id|
      f.write("<document type=\"music\" documentid=\"id:test:music:n=" + id.to_s + ":1\">\n")
      f.write("<bodyfield>")
      (size / 50).times {
         f.write("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n")
      }
      f.write("</bodyfield>")
      f.write("</document>")
    }
    f.write("</vespafeed>")
    f.close

    execute("vespa-feeder --maxpending 1 #{Environment.instance.vespa_home}/tmp/feedtmp")
    File.delete("#{Environment.instance.vespa_home}/tmp/feedtmp")
  end

  def check_dummy_feed(count, size)
    count.times { |id|
      documentid="id:test:music:n=" + id.to_s + ":1"
      execute("vespa-get " + documentid + " >#{Environment.instance.vespa_home}/tmp/gettmp")

      filesize = File.size("#{Environment.instance.vespa_home}/tmp/gettmp")
      File.delete("#{Environment.instance.vespa_home}/tmp/gettmp")

      return false if filesize < size
    }

    execute("vespa-visit --xmloutput --maxpending 1 --maxpendingsuperbuckets 1 --maxbuckets 1 >#{Environment.instance.vespa_home}/tmp/visittmp")
    filesize = File.size("#{Environment.instance.vespa_home}/tmp/visittmp")

    File.delete("#{Environment.instance.vespa_home}/tmp/visittmp")
    return false if filesize < (size * count)

    return true
  end

end
