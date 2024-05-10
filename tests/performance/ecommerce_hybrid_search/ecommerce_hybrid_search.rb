# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'

class EcommerceHybridSearchTest < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def test_hybrid_search
    set_description("Test performance of hybrid search using an E-commerce dataset (feeding, queries, re-feeding with queries)")
    deploy(selfdir + "app")
    @container = vespa.container.values.first
    start
    run_feeder_helper(feed_file_name(), "feed")
    run_fbench_helper("vespa_queries-weak_and-10k.json", "after_feed", "weak_and")
    run_fbench_helper("vespa_queries-semantic-10k.json", "after_feed", "semantic")
    run_fbench_helper("vespa_queries-hybrid-10k.json", "after_feed", "hybrid")
  end

  def feed_file_name(minimal=false)
    minimal ? "vespa_feed-10k.json.zst" : "vespa_feed-1M.json.zst"
  end

  def system_metric_filler(system_sampler)
    # This proc will end the system sampling (cpuutil) and fill the metrics to the given result model
    Proc.new do |result|
      system_sampler.end
      system_sampler.fill.call(result)
    end
  end

  def run_feeder_helper(feed_file, label)
    local_file = download_file(feed_file, vespa.adminserver)
    system_sampler = Perf::System::new(vespa.search["search"].first)
    system_sampler.start
    fillers = [parameter_filler("label", label), system_metric_filler(system_sampler)]
    run_feeder(local_file, fillers, {:client => :vespa_feed_client,
                                     :localfile => true,
                                     :silent => true,
                                     :disable_tls => true})
  end

  def run_fbench_helper(query_file, query_phase, query_type)
    local_file = download_file(query_file, @container)
    label = "#{query_phase}_#{query_type}"
    result_file = dirs.tmpdir + "result_#{label}.txt"
    fillers = [parameter_filler("label", label),
               parameter_filler("query_phase", query_phase),
               parameter_filler("query_type", query_type)]
    profiler_start
    run_fbench2(@container,
                local_file,
                {:runtime => 30,
                 :clients => 1,
                 :use_post => true,
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -12 #{result_file}")
  end

  def download_file(file_name, vespa_node)
    local_file = dirs.tmpdir + file_name
    vespa_node.fetchfiles(:testdata_url => "https://data.vespa.oath.cloud/tests/performance/ecommerce_hybrid_search",
                          :file => file_name,
                          :destination_file => local_file)
    local_file
  end

  def teardown
    super
  end

end
