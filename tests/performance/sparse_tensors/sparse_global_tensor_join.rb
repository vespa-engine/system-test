# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class SparseGlobalTensorJoinPerfTest < PerformanceTest

  TYPE = 'type'
  LABEL = 'label'
  CLIENTS = 'clients'
  FBENCH_TIME = 60
  SETUP = 'samequery'
  MEMORY = 'memory'
  QUERY = 'query'

  def create_app(num_threads = 1)
    searching = Searching.new
    app = SearchApp.new.
      sd(selfdir + 'globaltensors.sd', { :global => true }).
      sd(selfdir + 'twoperdoc.sd').
      threads_per_search(num_threads).
      container(Container.new('mycc').
                jvmoptions('-Xms2g -Xmx2g').
                search(searching).
                docproc(DocumentProcessing.new)).
      indexing('mycc')
    return app
  end

  def test_deserialized_sparse_tensors
    set_description('Test performance of sparse tensor joins')
    set_owner('arnej')
    deploy_app(create_app)
    start

    @container = vespa.container.values.first
    @searchnode = vespa.search['search'].first
    @queries_file_name = dirs.tmpdir + '/queries.txt'

    generate_queries
    feed(:file => selfdir+'one-global.json')
    feed_and_wait_for_docs('twoperdoc', 10429, :file => selfdir+'documents.json.gz')

    query_and_benchmark

    canary = '?query=sddocname:twoperdoc&hits=5&format=json'
    # save_result(canary, selfdir+'some-hits.json')
    assert_result(canary, selfdir+'some-hits.json')

    memstats = get_mem_stats
    memstats.each do |key, value|
      puts "memstat #{key} is #{value}"
      write_report([metric_filler(MEMORY, value),
                    parameter_filler(TYPE, MEMORY),
                    parameter_filler(LABEL, key)])
    end
  end

  def get_mem_stats
    result = {}
    [ 'doc_xxx', 'doc_yyy' ].each do |attr|
      uri = "/documentdb/twoperdoc/subdb/ready/attribute/#{attr}"
      stats = @searchnode.get_state_v1_custom_component(uri)
      alloc = stats['status']['memoryUsage']['allocatedBytes']
      inuse = stats['status']['memoryUsage']['usedBytes']
      pct = 100 * inuse / alloc
      puts "Memory stats for #{attr}: inuse #{inuse} / alloc #{alloc} = #{pct}%"
      result["#{attr}/alloc"] = alloc
      result["#{attr}/inuse"] = inuse
    end
    result
  end

  def generate_queries
    puts 'generate_queries'
    file = File.open(@queries_file_name, 'w')
    file.write("/search/?query=sddocname:twoperdoc&timeout=99\n")
    file.close
    remotedir = File.dirname(@queries_file_name)
    @container.copy(@queries_file_name, remotedir)
  end

  def query_and_benchmark
    clients = 1
    result_file = dirs.tmpdir + "fbench_result.#{SETUP}.txt"
    fillers = [parameter_filler(LABEL, SETUP),
               parameter_filler(TYPE, QUERY),
               parameter_filler(CLIENTS, clients)]
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => FBENCH_TIME,
                 :clients => clients,
                 :result_file => result_file},
                fillers)
    memusage = @searchnode.memusage_rss(@searchnode.get_pid)
    write_report([metric_filler(MEMORY, memusage),
                  parameter_filler(TYPE, MEMORY),
                  parameter_filler(LABEL, 'searchnode.rss')])
    puts "Mem usage (rss): #{memusage}"
    profiler_report(SETUP)
    @container.execute("head -15 #{result_file}")
  end

end
