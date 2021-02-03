# coding: utf-8
# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'

class DocumentV1Throughput < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    900
  end

  def setup
    super
    set_description("Stress test document/v1 API POST and GET")
    set_owner("jvenstad")
    @test_config = {
      {
        :legend => 'POST small data 4 clients',
        :fbench => { :clients => 4, :use_post => true },
        :data => "{ \"fields\": { \"text\": \"GNU's not UNIX\" } }"
      } => {
        'qps' => { :y_min =>  2550, :y_max =>  3300 },
        '95p' => { :y_min =>   1.4, :y_max =>   1.7 }
      },
      {
        :legend => 'GET small data 4 clients',
        :fbench => { :clients => 4, :use_post => false }
      } => {
        'qps' => { :y_min =>  5650, :y_max =>  6300 },
        '95p' => { :y_min =>   0.7, :y_max =>   0.9 }
      },
      {
        :legend => 'POST large data 128 clients',
        :fbench => { :clients => 128, :use_post => true},
        :data => "{ \"fields\": { \"text\": \"GNU#{"'s not UNIX" * (1 << 10) }\" } }"
      } => {
        'qps' => { :y_min =>  6200, :y_max =>  6700 },
        '95p' => { :y_min =>    23, :y_max =>    28 }
      },
      {
        :legend =>  'GET large data 128 clients',
        :fbench => { :clients => 128, :use_post => false }
      } => {
        'qps' => { :y_min => 31000, :y_max => 36000 },
        '95p' => { :y_min =>   4.5, :y_max =>   5.5 }
      }
    }
    @graphs = get_graphs
  end

  def test_throughput
    deploy_app(SearchApp.new.monitoring("vespa", 60).
               container(Container.new("combinedcontainer").
                         jvmargs('-Xms16g -Xmx16g').
                         search(Searching.new).
                         docproc(DocumentProcessing.new).
                         gateway(ContainerDocumentApi.new)).
               admin_metrics(Metrics.new).
               indexing("combinedcontainer").
               sd(selfdir + "text.sd"))

    start
    benchmark_operations
  end

  def benchmark_operations
    qrserver = @vespa.container["combinedcontainer/0"]
    @test_config.keys.each do |config|
      operations = (1..1024).map do |i|
        "/document/v1/test/text/docid/#{i}#{"\n#{config[:data]}" if config[:data]}"
      end.join("\n")
      legend = config[:legend].gsub(/\s/, '_')
      operations_file = dirs.tmpdir + legend + ".txt"
      qrserver.writefile(operations, operations_file)
      # Warmup — no legend
      run_fbench2(qrserver,
                  operations_file,
                  { :runtime => 10 }.merge(config[:fbench]))
      # Benchmark
      profiler_start
      run_fbench2(qrserver,
                  operations_file,
                  { :runtime => 30 }.merge(config[:fbench]),
                  [ parameter_filler("legend", config[:legend]) ])
      profiler_report(legend)
    end
  end

  def get_graphs
    @test_config.map do |config, metrics|
      metrics.map do |metric, limits|
        {
          :x => "legend",
          :y => metric,
          :title => "/document/v1 #{config[:legend]} #{metric}",
          :filter => { "legend" => config[:legend] },
          :historic => true
        }.merge(limits)
      end
    end.flatten
  end

  def teardown
    super
  end

end
