# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'
require 'securerandom'

class ClusterDynamicDistributionTest < VdsTest

  def initialize(*args)
    super(*args)
  end

  def setup
    @num_docs = 10000
    @num_users = 100
    set_owner("vekterli")
    set_expected_logged(/pidfile/)
    @feedfile = "#{SecureRandom.urlsafe_base64}_tmpfeed_cluster_dynamic.json"
    make_feed_file(@feedfile, "music", 0, @num_users - 1, @num_docs / @num_users)
    deploy_app(default_app.num_nodes(3).redundancy(2).distribution_bits(8))
    start
  end

  def teardown
    begin
      if File.exist?(@feedfile)
        File.delete(@feedfile)
      end
      # If things went belly-up, visiting thread/process might still be active
      content_node(0).execute("pkill -KILL -f vespa-feeder", :exceptiononfailure => false);
    ensure
      stop
    end
  end

  def wait_until_state_updated(nodecount, bits, timeout=60)
    time_started = Time.new
    while true
      puts "Waiting for updated state..."
      nodes = []
      cluster = vespa.storage['storage']
      cluster.storage.each_value { |v| nodes << v }
      cluster.distributor.each_value { |v| nodes << v }
      # Coerce all nodes into updating their internal metrics
      nodes.each do |node|
        begin
          node.get_metrics_matching(".*", true)
        rescue => e
          puts "Ignoring connection error to node #{node.index}, assuming it is not yet up"
        end
      end
      state = vespa.storage["storage"].get_master_fleet_controller.get_cluster_state.to_s
      puts "State is: '#{state}', waiting for #{bits} bits and #{nodecount} nodes"
      break if state =~ /bits:#{bits}/ and state =~ /storage:#{nodecount}/ and state =~ /distributor:#{nodecount}/
      time_now = Time.new
      if time_now - time_started > timeout
        flunk("Timeout waiting for state update")
      end
    end
    puts "State has been updated"
  end

  def start_feed_thread
    puts "Starting feeding in own thread"
    feed_thread = Thread.new {
      feed_start = Time.new
      feedfile(@feedfile)
      puts "Feeding took " + (Time.new - feed_start).to_s + " seconds"
    }
    feed_thread
  end

  def content_node(distribution_key)
    vespa.content_node("storage", distribution_key)
  end

  def storage_node(distribution_key)
    vespa.storage['storage'].storage[distribution_key.to_s]
  end
  def distributor(distribution_key)
    vespa.storage['storage'].distributor[distribution_key.to_s]
  end

  def verify_document_count_is(expected_doc_count)
    actual_doc_count = content_node(0).execute("vespa-visit -i 2>/dev/null | grep 'id:music' | wc -l")
    assert_equal(expected_doc_count, actual_doc_count.strip.to_i)
  end

  def redeploy_with_14_distribution_bits
    puts "Redeploying with 14 distribution bits"
    deploy_app(default_app.num_nodes(3).redundancy(2).distribution_bits(14))
  end

  def test_storage_node_down_with_outdated_distribution
    feed_thread = start_feed_thread
    puts "Taking down storage node"
    vespa.stop_content_node("storage", 1)

    feed_thread.join

    puts "Checking document count before redeploy"
    verify_document_count_is @num_docs

    redeploy_with_14_distribution_bits
    puts "Restarting downed storage node"
    vespa.start_content_node("storage", 1)
    wait_until_state_updated(3, 14)
    vespa.storage["storage"].wait_until_ready(300)

    puts "Verifying all documents are accessible after redistribution"
    verify_document_count_is @num_docs
  end

  def test_distributor_down_with_outdated_distribution
    feed_thread = start_feed_thread
    puts "Taking down distributor node"
    distributor(1).stop
    distributor(1).wait_for_current_node_state('d')

    feed_thread.join
    vespa.storage["storage"].wait_until_ready(300, ['1'])

    puts "Checking document count before redeploy"
    verify_document_count_is @num_docs

    redeploy_with_14_distribution_bits
    puts "Restarting downed distributor node"
    distributor(1).start
    distributor(1).wait_for_current_node_state('u')
    wait_until_state_updated(3, 14)
    vespa.storage["storage"].wait_until_ready(300)

    puts "Verifying all documents are accessible after redistribution"
    verify_document_count_is @num_docs
  end
end
