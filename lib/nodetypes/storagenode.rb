# Copyright Vespa.ai. All rights reserved.

require 'nodetypes/vdsnode'
require 'bucket_copy'

class StorageNode < VDSNode

  # Wait until Proton has completed all internal bucket move operations, if any.
  #
  # This reduces the time window of where a search node may trigger a distributor to perform ideal
  # state operations that it originally did not know about. For instance, if
  # a search node is doing background indexing it will tell the distributor
  # about buckets when they are indexed. This act might trigger bucket activation
  # which in turn might race with bucket database cross-checking from the
  # system test framework.
  #
  # Note that this is not foolproof; it's still possible to encounter a race
  # with the asynchronous notification from the search node to the distributor
  # after all move operations have been completed. However, as mentioned, this
  # time window should be very limited.
  def wait_until_no_pending_bucket_moves
    while true
      move_ops = get_metrics_matching('content.proton.documentdb\\{.*\\}.bucket_move.buckets_pending', true)
      max_moves_found = 0
      move_ops.reject{|k, v| v.empty?}.each_value do |metric|
        max_moves_found = [max_moves_found, metric['last'].to_f].max
      end
      break if max_moves_found == 0
      @testcase.output("Waiting for bucket move operations to complete (#{max_moves_found})")
      sleep 1
    end
  end

  # Add a mapping of parsed bucket id -> StorageBucketCopy
  def add_storage_bucket_state(mapping, line)
    # All the cool and hip kids parse XML using regular expressions!
    if line =~ /<bucket id="0x([0-9a-f]+)" checksum="(0x[a-f0-9]+)" docs="(\d+)" size="(\d+)" metacount="(\d+)" usedfilesize="(\d+)" ready="(\d+)" active="(\d+)" lastmodified="(\d+)"\/>/
      crc = $~[2].to_i(16)
      docs = $~[3].to_i
      bytes = $~[4].to_i
      metacount = $~[5].to_i
      usedfilesize = $~[6].to_i
      ready = $~[7] == "1"
      active = $~[8] == "1"
      disk = 0 # TODO remove
      mapping[$~[1]] = StorageBucketCopy.new(crc, docs, metacount, bytes,
                                             usedfilesize, disk, ready, active)
    else
      # ignore
    end
  end

  def get_buckets
    content = get_status_page('/bucketdb?showall')

    current_space = 'default'
    idx = @index.to_i
    bucket_state = { current_space => {} }
    content.each_line do |line|
      if line =~ /<bucket-space name="([a-z]+)">/
        current_space = $~[1]
        bucket_state[current_space] = {}
      else
        add_storage_bucket_state(bucket_state[current_space], line)
      end
    end
    bucket_state
  end

  def get_bucket_count(bucket_space = 'default')
    get_buckets()[bucket_space].size
  end

end
