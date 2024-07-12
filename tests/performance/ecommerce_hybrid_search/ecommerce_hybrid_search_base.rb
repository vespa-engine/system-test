# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'

class EcommerceHybridSearchTestBase < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def system_metric_filler(system_sampler)
    # This proc will end the system sampling (cpuutil) and fill the metrics to the given result model
    Proc.new do |result|
      system_sampler.end
      system_sampler.fill.call(result)
    end
  end

  def download_file(file_name, vespa_node)
    download_file_from_s3(file_name, vespa_node, "/ecommerce_hybrid_search")
  end

  def run_fbench_helper(query_file, query_phase, query_type, clients, vespa_node, params={})
    node_file = download_file(query_file, vespa_node)
    label = "#{query_phase}_#{query_type}_#{clients}"
    result_file = dirs.tmpdir + "result_#{label}.txt"
    fillers = [parameter_filler("label", label),
               parameter_filler("query_phase", query_phase),
               parameter_filler("query_type", query_type),
               parameter_filler("clients", clients)]
    profiler_start
    params[:runtime] = 20 unless params[:runtime]
    run_fbench2(vespa_node,
                node_file,
                {:clients => clients,
                 :use_post => true,
                 :result_file => result_file}.merge(params),
                fillers)
    profiler_report(label)
    vespa_node.execute("head -12 #{result_file}")
  end

  def teardown
    super
  end

end
