
# coding: utf-8
# Copyright 2020 Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'

class ReindexingAndFeeding < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    900
  end

  def setup
	  super
	  set_description("Measure throughput of reindexing, and its impact on external updates and puts")
	  set_owner("jvenstad")
	  @test_config = {
		  {
			  :legend => 'Reindexing',
			  :fbench => { :clients => 4, :use_post => true },
			  :data => "{ \"fields\": { \"text\": \"GNU's not UNIX\" } }"
		  } => {
			  'qps' => { :y_min =>  2650, :y_max =>  3250 },
			  '95p' => { :y_min =>   1.4, :y_max =>   1.7 }
		  },
		  {
			  :legend => 'GET small data 4 clients',
			  :fbench => { :clients => 4, :use_post => false }
		  } => {
			  'qps' => { :y_min =>  5600, :y_max =>  6250 },
			  '95p' => { :y_min =>   0.7, :y_max =>   0.9 }
		  },
		  {
			  :legend => 'POST large data 128 clients',
			  :fbench => { :clients => 128, :use_post => true},
			  :data => "{ \"fields\": { \"text\": \"GNU#{"'s not UNIX" * (1 << 10) }\" } }"
		  } => {
			  'qps' => { :y_min =>  6300, :y_max =>  6700 },
			  '95p' => { :y_min =>    24, :y_max =>    28 }
		  },
		  {
			  :legend =>  'GET large data 128 clients',
			  :fbench => { :clients => 128, :use_post => false }
		  } => {
			  'qps' => { :y_min => 29500, :y_max => 33000 },
			  '95p' => { :y_min =>   4.9, :y_max =>   5.5 }
		  }
	  }
	  @graphs = get_graphs
	  @app = SearchApp.new.monitoring("vespa", 60).
		  container(Container.new("combinedcontainer").
			    jvmargs('-Xms16g -Xmx16g').
			    search(Searching.new).
			    docproc(DocumentProcessing.new).
			    gateway(ContainerDocumentApi.new)).
	  admin_metrics(Metrics.new).
	  indexing("combinedcontainer").
	  sd(selfdir + "doc.sd")
  end

  def test_reindexing_performance_and_impact
    deploy_app(@app)
    start

    # First time is a dummy.
    trigger_reindexing
    wait_for_reindexing

    qrserver = @vespa.container["combinedcontainer/0"]
    document_count = 1 << 20

    initial_file = dirs.tmpdir + "initial.json"
    puts "Writing initial data to " + initial_file
    qrserver.write_document_operations(:put,
				       { :fields => { :label => 'initial', :count => 0, :text => "FAST#{" Search and Transfer" * (1 << 6)}" } },
				       'id:test:doc::',
				       document_count,
				       initial_file)

    refeed_file = dirs.tmpdir + "refeed.json"
    puts "Writing refeed data to " + refeed_file
    qrserver.write_document_operations(:put,
				       { :fields => { :label => 'refeed', :count => 0, :text => "FAST#{" Search and Transfer" * (1 << 6)}" } },
				       'id:test:doc::',
				       document_count / 2,
				       refeed_file)

    updates_file = dirs.tmpdir + "updates.json"
    puts "Writing updates to " + updates_file
    qrserver.write_document_operations(:update,
				       { :fields => { :count => { :increment => 1 } } },
				       'id:test:doc::',
				       document_count,
				       updates_file)

    # Warmup and feed corpus
    puts "Feeding initial data"
    feed_data({ :file => initial_file })

    # Benchmark pure reindexing
    puts "Reindexing corpus"
    sleep 2
    now_seconds = Time.now.to_i
    assert_hitcount("indexed_at_seconds:%3C#{now_seconds}&nocache", document_count)	# All documents should be indexed before now_seconds
    trigger_reindexing
    reindexing_millis = wait_for_reindexing
    assert_hitcount("indexed_at_seconds:%3E#{now_seconds}&nocache", document_count) # All documents should be indexed after now_seconds
    write_report([ reindexing_result_filler(reindexing_millis, document_count, 'reindex') ])

    # Benchmark concurrent reindexing and feed
    puts "Reindexing corpus while refeeding half of it"
    sleep 2
    now_seconds = Time.now.to_i
    assert_hitcount("indexed_at_seconds:%3C#{now_seconds}&nocache", document_count)	# All documents should be indexed before now_seconds
    trigger_reindexing
    feed_data({ :file => refeed_file, :legend => 'reindex_feed' })
    reindexing_millis = wait_for_reindexing
    assert_hitcount("indexed_at_seconds:%3E#{now_seconds}&nocache", document_count) # All documents should be indexed after now_seconds
    assert_hitcount("label:refeed&nocache", document_count / 2)			# Half the documents should have the "refeed" label
    assert_hitcount("label:initial&nocache", document_count / 2)		# The other half should still have the "initial" label
    write_report([ reindexing_result_filler(reindexing_millis, document_count, 'reindex_feed') ])

    # Benchmark pure feed
    puts "Refeeding half the corpus"
    feed_data({ :file => refeed_file, :legend => 'feed' })

    # Benchmark concurrent reindexing and updates
    puts "Reindexing corpus while doing partial updates to all documents"
    sleep 2
    now_seconds = Time.now.to_i
    assert_hitcount("indexed_at_seconds:%3C#{now_seconds}&nocache", document_count)	# All documents should be indexed before now_seconds
    trigger_reindexing
    feed_data({ :file => updates_file, :legend => 'reindex_update' })
    reindexing_millis = wait_for_reindexing
    assert_hitcount("indexed_at_seconds:%3E#{now_seconds}&nocache", document_count) # All documents should be indexed after now_seconds
    assert_hitcount("count:1&nocache", document_count)					# All documents should have "counter" incremented by 1
    write_report([ reindexing_result_filler(reindexing_millis, document_count, 'reindex_update') ])

    # Benchmark pure partial updates
    puts "Doing partial updates to all documents"
    feed_data({ :file => updates_file, :legend => 'update' })

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
    profiler_start if config.has_key?(:legend)
    run_feeder(config[:file], [], config.merge({ :localfile => true, :numthreads => 8 }))
    profiler_report(config[:legend]) if config.has_key?(:legend)
  end

  # Wait for reindexing after the given time to have started.
  def wait_for_reindexing_start(ready_millis)
    while true
      status = get_reindexing_status
      break if status and status['startedMillis'] > ready_millis
      sleep 1
    end
  end

  # Wait for reindexing to successfully complete, and return the time used in milliseconds.
  def wait_for_reindexing
    while true
      status = get_reindexing_status
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
    return status['status'].first
  end


  def get_graphs
    @test_config.map do |config, metrics|
      metrics.map do |metric, limits|
        {
          :x => "blank",
          :y => metric,
          :title => " #{config[:legend]} #{metric}",
          :filter => { "legend" => config[:legend] },
          :historic => true
        }.merge(limits)
      end
    end.flatten
  end

  # Wait for convergence of all services in the application — specifically document processors 
  def wait_for_convergence(generation)
    start_time = Time.now
    until get_json(http_request(URI(application_url + "serviceconverge"), {}))["converged"] or Time.now - start_time > 60 # seconds
      sleep 1
    end
    assert(Time.now - start_time < 60, "Services should converge on new generation within the minute")
    assert(generation == get_json(http_request(URI(application_url + "serviceconverge"), {}))["wantedGeneration"],
           "Should converge on generation #{generation}")
    puts "Services converged on new config generation after #{Time.now - start_time} seconds"
  end

  # Trigger reindexing of the whole corpus
  def trigger_reindexing
    # Read baseline reindexing status — very first reindexing is a no-op in the reindexer controller
    response = http_request(URI(application_url + "reindexing"), {})
    assert(response.code.to_i == 200, "Request should be successful")
    previous_reindexing_timestamp = get_json(response)["status"]["readyMillis"]

    # Allow the reindexing maintainer some time to run, and mark the first no-op reindexing as done
    sleep 60

    # Trigger reindexing through reindexing API in /application/v2, and verify it was triggered
    response = http_request_post(URI(application_url + "reindex"), {})
    assert(response.code.to_i == 200, "Request should be successful")

    response = http_request(URI(application_url + "reindexing"), {})
    assert(response.code.to_i == 200, "Request should be successful")
    current_reindexing_timestamp = get_json(response)["status"]["readyMillis"]
    assert(previous_reindexing_timestamp < current_reindexing_timestamp,
           "Previous reindexing timestamp (#{previous_reindexing_timestamp}) should be after current (#{current_reindexing_timestamp})")

    deploy_app(@app)
    wait_for_reindexing_start(current_reindexing_timestamp)
  end

  # Application and tenant names change based on the context this is run in.
  def application_url
    tenant = use_shared_configservers ? @tenant_name : "default"
    application = use_shared_configservers ? @application_name : "default"
    "https://#{vespa.nodeproxies.first[1].addr_configserver[0]}:#{19071}/application/v2/tenant/#{tenant}/application/#{application}/environment/prod/region/default/instance/default/"
  end

  def teardown
    super
  end

end
