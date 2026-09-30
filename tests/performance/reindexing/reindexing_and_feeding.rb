# coding: utf-8
# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'reindexing'

class ReindexingAndFeedingTest < PerformanceTest

  include Reindexing

  CLUSTER_ID = 'search'
  DOCUMENT_TYPE = 'doc'

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    3000
  end

  def setup
    super
    set_description("Measure throughput of reindexing, and its impact on external updates and puts")
    set_owner("hmusum")
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
    start_reindexing
    reindexing_millis = wait_for_reindexing_to_complete(CLUSTER_ID, DOCUMENT_TYPE)
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
    start_reindexing
    feed_data({ :file => @refeed_file, :legend => 'reindex_feed' })
    reindexing_millis = wait_for_reindexing_to_complete(CLUSTER_ID, DOCUMENT_TYPE)
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
    start_reindexing
    feed_data({ :file => @updates_file, :legend => 'reindex_update', :max_streams_per_connection => 32, :numconnections => 8 })
    feed_data({ :file => @updates_file, :legend => 'reindex_update', :max_streams_per_connection => 32, :numconnections => 8 })
    reindexing_millis = wait_for_reindexing_to_complete(CLUSTER_ID, DOCUMENT_TYPE)
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

  # Trigger reindexing of the whole corpus, and wait for it to start
  def start_reindexing
    ready = trigger_reindexing(@app)
    wait_for_reindexing_to_start(CLUSTER_ID, DOCUMENT_TYPE, ready[CLUSTER_ID][DOCUMENT_TYPE])
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


end
