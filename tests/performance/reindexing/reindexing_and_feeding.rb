# coding: utf-8
# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'

class ReindexingAndFeedingTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    3000
  end

  def setup
    super
    set_description("Measure throughput of reindexing, and its impact on external updates and puts")
    set_owner("jvenstad")
  end

  def test_reindexing_performance_and_impact
    @app = SearchApp.new.monitoring("vespa", 60).
      container(Container.new("combinedcontainer").
		jvmoptions('-Xms16g -Xmx16g').
		search(Searching.new).
		docproc(DocumentProcessing.new).
		documentapi(ContainerDocumentApi.new)).
    admin_metrics(Metrics.new).
    indexing("combinedcontainer").
    sd(selfdir + "doc.sd")

    deploy_app(@app)
    start

    @qrserver = @vespa.container["combinedcontainer/0"]
    @document_count = 300_000
    generate_feed

    # Warmup and feed corpus
    puts "Feeding initial data"
    feed_data({ :file => @initial_file, :legend => 'initial' })
    assert_hitcount("sddocname:doc", @document_count) # All documents should be fed and visible

    benchmark_reindexing
    benchmark_reindexing_and_refeeding
    benchmark_feeding
    benchmark_reindexing_and_updates
    benchmark_updates
  end

  def benchmark_reindexing
    # Benchmark pure reindexing
    puts "Reindexing corpus"
    sleep 10
    profiler_start
    now_seconds = Time.now.to_i                                                         # Account for clock skew
    assert_hitcount("indexed_at_seconds:%3C#{now_seconds}&nocache", @document_count)	# All documents should be indexed before now_seconds
    sleep 10
    trigger_reindexing
    reindexing_millis = wait_for_reindexing
    assert_hitcount("indexed_at_seconds:%3E#{now_seconds}&nocache", @document_count) 	# All documents should be indexed after now_seconds
    write_report([ reindexing_result_filler(reindexing_millis, @document_count, 'reindex') ])
    puts "Reindexed #{@document_count} documents in #{reindexing_millis * 1e-3} seconds"
    profiler_report('reindex')
  end

  def benchmark_reindexing_and_refeeding
    # Benchmark concurrent reindexing and feed
    puts "Reindexing corpus while refeeding two thirds of it"
    sleep 10
    profiler_start
    now_seconds = Time.now.to_i    							# Account for clock skew
    assert_hitcount("indexed_at_seconds:%3C#{now_seconds}&nocache", @document_count)	# All documents should be indexed before now_seconds
    sleep 10
    trigger_reindexing
    feed_data({ :file => @refeed_file, :legend => 'reindex_feed' })
    reindexing_millis = wait_for_reindexing
    assert_hitcount("indexed_at_seconds:%3E#{now_seconds}&nocache", @document_count) 	# All documents should be indexed after now_seconds
    assert_hitcount("label:refeed&nocache", @document_count * 2/ 3)			# Two thirds of the documents should have the "refeed" label
    assert_hitcount("label:initial&nocache", @document_count * 1 / 3)			# The last third should still have the "initial" label
    write_report([ reindexing_result_filler(reindexing_millis, @document_count, 'reindex_feed') ])
    puts "Reindexed #{@document_count} documents in #{reindexing_millis * 1e-3} seconds"
    profiler_report('reindex_feed')
  end

  def benchmark_feeding
    # Benchmark pure feed
    puts "Refeeding two thirds of the corpus"
    profiler_start
    feed_data({ :file => @refeed_file, :legend => 'feed' })
    profiler_report('feed')
  end

  def benchmark_reindexing_and_updates
    # Benchmark concurrent reindexing and updates
    puts "Reindexing corpus while doing partial updates to all documents"
    sleep 10
    profiler_start
    now_seconds = Time.now.to_i    							# Account for clock skew
    assert_hitcount("indexed_at_seconds:%3C#{now_seconds}&nocache", @document_count)	# All documents should be indexed before now_seconds
    sleep 10
    trigger_reindexing
    feed_data({ :file => @updates_file, :legend => 'reindex_update', :numconnections => 2 })
    feed_data({ :file => @updates_file, :legend => 'reindex_update', :max_streams_per_connection => 512 })
    reindexing_millis = wait_for_reindexing
    assert_hitcount("indexed_at_seconds:%3E#{now_seconds}&nocache", @document_count) 	# All documents should be indexed after now_seconds
    assert_hitcount("count:2&nocache", @document_count)					# All documents should have "counter" incremented by 2
    write_report([ reindexing_result_filler(reindexing_millis, @document_count, 'reindex_update') ])
    puts "Reindexed #{@document_count} documents in #{reindexing_millis * 1e-3} seconds"
    profiler_report('reindex_update')
  end

  def benchmark_updates
    # Benchmark pure partial updates
    puts "Doing partial updates to all documents"
    profiler_start
    feed_data({ :file => @updates_file, :legend => 'update' })
    profiler_report('update')
  end

  def reindexing_result_filler(time_millis, document_count, concurrent_operations)
    Proc.new do |result|
      result.add_metric('reindexing.time.seconds', time_millis * 1e-3)
      result.add_metric('reindexing.throughput', document_count * 1e3 / time_millis)
      result.add_parameter('legend', concurrent_operations)
    end
  end

  # Feed data with the given config, which must include :file.
  def feed_data(config)
    run_feeder(config[:file],
               [ parameter_filler('legend', config[:legend]) ],
               { :localfile => true, :feed_node => @qrserver }.merge(config))
  end

  # Wait for reindexing after the given time to have started.
  def wait_for_reindexing_start(ready_millis)
    puts "Waiting for reindexing to start, after #{Time.at(ready_millis / 1000)}"
    while true
      status = get_reindexing_status
      puts "Reindexing status: #{status}" if Time.now.sec % 10 == 0
      break if status and status['startedMillis'] > ready_millis
      sleep 1
    end
  end

  # Wait for reindexing to successfully complete, and return the time used in milliseconds.
  def wait_for_reindexing
    puts "Waiting for reindexing to complete"
    while true
      status = get_reindexing_status
      puts "Reindexing status: #{status}" if Time.now.sec % 10 == 0
      break if status and ["successful", "failed"].include? status['state']
      sleep 1
    end
    assert("successful" == status['state'], "Reindexing should complete successfully")
    return status['endedMillis'] - status['startedMillis']
  end

  # Fetch reindexing status from reindexing controller.
  def get_reindexing_status
    status = vespa.clustercontrollers["0"].get_reindexing_json
    return nil if status.nil?
    cluster = status['clusters']['search']
    return nil if cluster.nil?
    return cluster['documentTypes']['doc']
  end

  def generate_feed
    @initial_file = dirs.tmpdir + "initial.json"
    puts "Writing initial data to " + @initial_file
    @qrserver.write_document_operations(:put,
					{ :fields => { :label => 'initial', :count => 0, :text => "FAST#{" Search and Transfer" * (1 << 6)}" } },
					'id:test:doc::',
					@document_count,
					@initial_file)

    @refeed_file = dirs.tmpdir + "refeed.json"
    puts "Writing refeed data to " + @refeed_file
    @qrserver.write_document_operations(:put,
					{ :fields => { :label => 'refeed', :count => 0, :text => "FAST#{" Search and Transfer" * (1 << 6)}" } },
					'id:test:doc::',
					@document_count * 2 / 3,
					@refeed_file)

    @updates_file = dirs.tmpdir + "updates.json"
    puts "Writing updates to " + @updates_file
    @qrserver.write_document_operations(:update,
					{ :fields => { :count => { :increment => 1 } } },
					'id:test:doc::',
					@document_count,
					@updates_file)
  end

  # Trigger reindexing of the whole corpus
  def trigger_reindexing
    # Read baseline reindexing status — very first reindexing is a no-op in the reindexer controller
    response = http_request(URI(application_url + "reindexing"), {})
    puts response.body unless response.code.to_i == 200
    assert(response.code.to_i == 200, "Request should be successful")
    previous_reindexing_timestamp = get_json(response)["clusters"]["search"]["ready"]["doc"]["readyMillis"]

    # Trigger reindexing through reindexing API in /application/v2, and verify it was triggered
    response = http_request_post(URI(application_url + "reindex"), {})
    puts response.body unless response.code.to_i == 200
    assert(response.code.to_i == 200, "Request should be successful")

    response = http_request(URI(application_url + "reindexing"), {})
    puts response.body unless response.code.to_i == 200
    assert(response.code.to_i == 200, "Request should be successful")
    current_reindexing_timestamp = get_json(response)["clusters"]["search"]["ready"]["doc"]["readyMillis"]
    assert(previous_reindexing_timestamp.nil? || previous_reindexing_timestamp < current_reindexing_timestamp,
	   "Previous reindexing timestamp (#{previous_reindexing_timestamp}) should be after current (#{current_reindexing_timestamp})")

    deploy_app(@app)
    wait_for_reindexing_start(current_reindexing_timestamp)
  end

  # Application and tenant names change based on the context this is run in.
  def application_url
    tenant = use_shared_configservers ? @tenant_name : "default"
    application = use_shared_configservers ? @application_name : "default"
    "http://#{vespa.nodeproxies.first[1].addr_configserver[0]}:#{19071}/application/v2/tenant/#{tenant}/application/#{application}/environment/prod/region/default/instance/default/"
  end

  def teardown
    super
  end

end
