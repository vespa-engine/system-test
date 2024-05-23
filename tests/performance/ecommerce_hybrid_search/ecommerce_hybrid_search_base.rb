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

  def download_file(file_name, vespa_node, url="https://data.vespa.oath.cloud/tests/performance/ecommerce_hybrid_search")
    if File.exists?(selfdir + file_name)
      # Place the file in the test directory to avoid downloading during manual testing.
      puts "Using local file: #{file_name}"
      selfdir + file_name
    else
      node_file = dirs.tmpdir + file_name
      if execute(vespa_node, "test -f #{node_file}")[0] == 0
        puts "Using already downloaded file: #{file_name}"
      else
        puts "Downloading file: #{file_name}"
        vespa_node.fetchfiles(:testdata_url => url,
                              :file => file_name,
                              :destination_file => node_file)
      end
      node_file
    end
  end

  def run_fbench_helper(query_file, query_phase, query_type, vespa_node, params={})
    node_file = download_file(query_file, vespa_node)
    label = "#{query_phase}_#{query_type}"
    result_file = dirs.tmpdir + "result_#{label}.txt"
    fillers = [parameter_filler("label", label),
               parameter_filler("query_phase", query_phase),
               parameter_filler("query_type", query_type)]
    profiler_start
    run_fbench2(vespa_node,
                node_file,
                {:runtime => 30,
                 :clients => 1,
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
