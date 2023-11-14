# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'json_document_writer'

class SplitJoinReadinessTest < SearchTest

  def create_app(split_count: 2)
    SearchApp.new.sd(SEARCH_DATA + 'test.sd').
      cluster_name("mycluster").
      num_parts(2).redundancy(2).ready_copies(1).
      storage(StorageCluster.new("mycluster", 2).
              distribution_bits(8).
              bucket_split_count(split_count))
  end

  def setup
    set_owner('vekterli')
  end

  def should_debug_log?
    true
  end

  def teardown
    stop
  end

  class GroupDocFeedWriter
    def initialize(file_name)
      @writer = JsonDocumentWriter.new(File.open(file_name, 'w'))
    end

    def self.open(file_name, &block)
      w = new(file_name)
      return w unless block_given?
      yield w
      w.close()
    end

    def close
      @writer.close()
    end

    def write_docs(document_type:, group:, count:, from:)
      (from...(from + count)).each do |i|
        @writer.put("id:ns:#{document_type}:g=#{group}:#{i}", {'f1' => "cool doc #{i}"})
      end
    end
  end

  def logctl_all(component, path, levels)
    ['', '2'].each do |n|
      nth_component = "#{component}#{n}"
      vespa.adminserver.logctl("#{nth_component}:#{path}", levels)
    end
  end

  def enable_debug_logging
    logctl_all('distributor', 'distributor.stripe_bucket_db_updater', 'debug=on,spam=on')
    logctl_all('distributor', 'distributor.operation.queue', 'debug=on,spam=off')
    logctl_all('distributor', 'distributor.operation.idealstate.setactive', 'debug=on,spam=on')
    logctl_all('distributor', 'distributor.operation.idealstate.split', 'debug=on,spam=on')
    logctl_all('distributor', 'distributor.operation.idealstate.join', 'debug=on,spam=on')
    logctl_all('searchnode', 'proton.server.bucketmovejob', 'debug=on,spam=off')
    logctl_all('searchnode', 'proton.server.buckethandler', 'debug=on,spam=off')
    logctl_all('searchnode', 'persistence.filestor.modifiedbucketchecker', 'debug=on,spam=on')
  end

  def disable_debug_logging
    logctl_all('distributor', '', 'debug=off,spam=off')
    logctl_all('searchnode', '', 'debug=off,spam=off')
  end

  def this_cluster
    vespa.storage['mycluster']
  end

  def wait_until_bucket_move_jobs_done
    this_cluster.storage.each do |index, node|
      node.wait_until_no_pending_bucket_moves
    end

    # Added sleep makes edge case more likely to happen, even after waiting for move jobs to finish.
    sleep 5
  end

  def check_readiness_of_primary_replicas_error_or_nil
    error = nil
    this_cluster.distributor.each do |key, node|
      node.each_database_bucket do |space, bucket_id, parsed_state, raw_state|
        # First replica is most ideal replica, and should be ready+active.
        first_replica = parsed_state[0]
        error = "#{bucket_id}: primary (1st) ideal replica not ready: #{raw_state}" if not first_replica.ready
        error = "#{bucket_id}: primary (1st) ideal replica not active: #{raw_state}" if not first_replica.active
        # Second replica should be de-indexed and inactive
        second_replica = parsed_state[1]
        error = "#{bucket_id}: non-primary (2nd) replica still ready: #{raw_state}" if second_replica.ready
        error = "#{bucket_id}: non-primary (2nd) replica still active: #{raw_state}" if second_replica.active
      end
    end
    error
  end

  def readiness_convergence_timeout_sec
    60
  end

  def verify_readiness_of_primary_replicas
    start = Time.now
    # Replica readiness updates are communicated and propagated asynchronously from Proton
    # via the persistence layer and finally to the distributor. To avoid spurious failures,
    # ensure we retry in the face of transient (but expected) inconsistencies.
    while true
      last_error = check_readiness_of_primary_replicas_error_or_nil
      return if last_error.nil?
      flunk(last_error) if (Time.now - start) > readiness_convergence_timeout_sec
      puts "Bucket DBs across nodes not yet in sync, retrying; #{last_error}"
      sleep 1
    end
  end

  def feed_docs_to_same_location
    feed_file = dirs.tmpdir + 'groupdocs.json'

    GroupDocFeedWriter.open(feed_file) do |w|
      w.write_docs(document_type: 'test', group: 'g1', from: 1, count: 11)
    end

    feed(:file => feed_file)
    wait_until_ready
  end

  def test_split_target_with_changed_ready_state_triggers_bucket_move
    set_description('Test that buckets split with altered ideal state are (de-)indexed as expected')
    deploy_app(create_app(split_count: 2))
    start

    enable_debug_logging if should_debug_log?
    feed_docs_to_same_location

    wait_until_all_content_nodes_have_bucket_count(8)
    wait_until_bucket_move_jobs_done

    disable_debug_logging if should_debug_log?

    verify_readiness_of_primary_replicas
  end

  def wait_until_all_content_nodes_have_bucket_count(expected)
    while true
      matched_all = true
      this_cluster.storage.each do |key, node|
        actual = node.get_bucket_count
        if actual != expected
          puts "Content node #{key} still has #{actual} buckets, not #{expected}"
          matched_all = false
        end
      end
      break if matched_all
      sleep 2
    end
  end

  def test_join_target_with_changed_ready_state_triggers_bucket_move
    set_description('Test that buckets joined with altered ideal state are (de-)indexed as expected')
    deploy_app(create_app(split_count: 2))
    start

    enable_debug_logging if should_debug_log?
    feed_docs_to_same_location

    # Let buckets join. Ideal state will change for a subset of the target bucket(s).
    deploy_app(create_app(split_count: 20))

    wait_until_all_content_nodes_have_bucket_count(2)
    wait_until_ready

    disable_debug_logging if should_debug_log?

    verify_readiness_of_primary_replicas
  end

end

