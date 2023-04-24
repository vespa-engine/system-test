require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'json_document_writer'

class GetsDuringStateTransitionsTest < PerformanceTest

  FBENCH_WARMUP_RUNTIME_SEC = 10
  FBENCH_TRANSITION_RUNTIME_SEC = 45
  FBENCH_CLIENTS = 10
  STALE_READS = 'stale_reads'
  ENABLED = 'enabled'
  DISABLED = 'disabled'
  EDGE = 'edge'
  DOWN = 'down'
  UP = 'up'
  LEGEND = 'legend'

  def setup
    super
    set_owner('vekterli')
    @is_set_up = false
    @should_debug_log = false
    @doc_count = 256 * 4
    @query_file = nil
  end

  def teardown
    super
  end

  def create_app(enable_stale_reads:, use_btree_db: false)
    SearchApp.new.sd(SEARCH_DATA + 'music.sd').
    num_parts(3).redundancy(2).ready_copies(1).
    container(Container.new("combinedcontainer").
                            search(Searching.new).
                            docproc(DocumentProcessing.new).
                            documentapi(ContainerDocumentApi.new)).
    config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
                          add('simulated_db_pruning_latency_msec', 2000).
                          add('simulated_db_merging_latency_msec', 3000).
                          add('allow_stale_reads_during_cluster_state_transitions', enable_stale_reads).
                          add('use_btree_database', use_btree_db)).
    config(ConfigOverride.new('vespa.config.content.core.stor-server').
                          add('enable_dead_lock_detector', true).      # TODO temporary for debugging
                          add('dead_lock_detector_timeout_slack', 60). # TODO temporary for debugging
                          add('simulated_bucket_request_latency_msec', 4000)).
    config(ConfigOverride.new('vespa.config.content.fleetcontroller').
                          add('enable_two_phase_cluster_state_transitions', enable_stale_reads))
  end

  def puts_header(str)
    puts "-----"
    puts str
    puts "-----"
  end

  # Possible TODOs:
  #  - global docs?
  #  - safe vs forced set-node-state calls?
  #  - 16 distribution bits?
  
  def with_json_feed(file_name)
    raise 'No block given' if not block_given?
    json_writer = JsonDocumentWriter.new(File.open(file_name, 'w'))
    begin
      yield json_writer
    ensure
      json_writer.close()
    end
  end

  def doc_id(n)
    # fully GID-distributed doc IDs ensure uniform distribution across the entire superbucket space
    "id:foo:music::doc-#{n}"
  end

  def assert_only_http_200_returned(status_codes)
    if status_codes.size() != 1 or not status_codes.has_key? 200
      flunk "Expected only HTTP 200 responses, got #{status_codes.inspect}"
    end
  end

  def feed_n_documents(n)
    feed_file = dirs.tmpdir + 'state_transition_test_feed.json'
    with_json_feed(feed_file) do |json|
      n.times {|i|
        json.put(doc_id(i), {'title' => "Hello World from document #{i}!"})
      }
    end
    feed(:file => feed_file)
  end

  def prepare_query_file_for_n_documents(n)
    query_file = dirs.tmpdir + 'state_transition_test_queries.txt'
    File.open(query_file, 'w') do |f|
      n.times {|i|
        f.syswrite("/document/v1/foo/music/docid/doc-#{i}\n")
      }
    end
    query_file
  end

  def container
    vespa.container.values.first
  end

  def with_background_fbench(query_file:, clients:, runtime_sec:)
    raise "No block given" if not block_given?
    ret = {}
    fbench_thread = Thread.new {
      fbench = Perf::Fbench.new(container, container.name, container.http_port)
      fbench.clients = clients
      fbench.runtime = runtime_sec
      fbench.query(query_file)
      ret = fbench
    }
    puts "Waiting for fbench to complete..."
    begin
      yield
    ensure
      fbench_thread.join
    end
    ret
  end

  def conditionally_enable_debug_logging
    if @should_debug_log # does not work for proper multi-node tests, only meant for local testing
      ['', '2', '3'].each{ |d|
        vespa.adminserver.execute("vespa-logctl distributor#{d} debug=on > /dev/null")
      }
    end
  end

  def warm_up_container
    fbench = with_background_fbench(query_file: @query_file, clients: FBENCH_CLIENTS, runtime_sec: FBENCH_WARMUP_RUNTIME_SEC) do
      # Twiddle thumbs
    end
    assert_only_http_200_returned(fbench.http_status_code_distribution)
  end

  def prepare_feed_and_query
    feed_n_documents(@doc_count)
    @query_file = prepare_query_file_for_n_documents(@doc_count)
    container.copy(@query_file, dirs.tmpdir) # If running locally, just overwrites file with itself.
  end

  def my_cluster
    vespa.storage['search']
  end

  def restart_all_distributors
    [0, 1, 2].each {|i|
      my_cluster.distributor[i.to_s].restart
    }
    my_cluster.wait_for_node_count('distributor', 3, 'u')
    my_cluster.wait_until_ready
  end

  def post_process_fbench_results(fbench, stale_reads, edge)
    assert_only_http_200_returned(fbench.http_status_code_distribution)
    param_fillers = [parameter_filler(STALE_READS, stale_reads),
                     parameter_filler(EDGE, edge),
                     parameter_filler(LEGEND, "Max response time (#{STALE_READS}: #{stale_reads}, #{EDGE}: #{edge})")]
    write_report([fbench.fill] + param_fillers) # TODO system fill thingie?
  end

  def do_node_down_edge_during_load(stale_reads)
    puts_header "Testing node down during Get load"
    fbench = with_background_fbench(query_file: @query_file, clients: FBENCH_CLIENTS, runtime_sec: FBENCH_TRANSITION_RUNTIME_SEC) do
      sleep 10
      puts "Orchestrated take-down of node 0"
      my_cluster.get_master_cluster_controller.set_node_state('search', 'storage', 0, 's:m', 'safe')
    end
    post_process_fbench_results(fbench, stale_reads, DOWN)
  end

  def do_node_up_edge_during_load(stale_reads)
    puts_header "Testing taking node back up during Get load"
    fbench = with_background_fbench(query_file: @query_file, clients: FBENCH_CLIENTS, runtime_sec: FBENCH_TRANSITION_RUNTIME_SEC) do
      sleep 10
      puts "Taking node 0 back up"
      my_cluster.get_master_cluster_controller.set_node_state('search', 'storage', 0, 's:u', 'safe')
    end
    post_process_fbench_results(fbench, stale_reads, UP)
  end

  def for_each_test_permutation
    [ENABLED, DISABLED].each do |stale_reads|
      yield(stale_reads)
    end
  end

  def do_test_gets_during_state_transitions(stale_reads:)
    puts_header "Starting benchmark run of (stale reads: #{stale_reads})"
    deploy_app(create_app(enable_stale_reads: stale_reads == ENABLED, use_btree_db: true))
    if not @is_set_up
      start
      prepare_feed_and_query
      warm_up_container
      conditionally_enable_debug_logging
    end
    if @is_set_up
      # DB type is fixed after startup, so must restart all distributors explicitly
      restart_all_distributors
    end
    @is_set_up = true
    do_node_down_edge_during_load(stale_reads)
    do_node_up_edge_during_load(stale_reads)
  end

  def test_gets_during_state_transitions
    for_each_test_permutation { |stale_reads|
      do_test_gets_during_state_transitions(stale_reads: stale_reads)
    }
  end

end
 
