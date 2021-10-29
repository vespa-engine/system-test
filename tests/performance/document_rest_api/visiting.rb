# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'concurrent'

class Visiting < PerformanceTest

  def timeout_seconds
    1200
  end

  def setup
    super
    set_description("Test throughput of visit operations through /document/v1")
    set_owner("jonmv")
    @document_count = 1 << 21
    @document_template = '{ "put": "id:test:test::$seq()", "fields": { "text": "$words(5)", "number": $ints(1, 100) } }'
    @document_update = '{ "fields": { "number": { "increment": 100 } } }'
    @selection_1p = 'test.number % 100 == 0'
    @selection_100p = 'true'

    deploy_app(
      SearchApp.new.
      monitoring("vespa", 60).
      container(
        Container.new("combinedcontainer").
        jvmargs('-Xms16g -Xmx16g').
        docproc(DocumentProcessing.new).
        gateway(ContainerDocumentApi.new)).
      admin_metrics(Metrics.new).
      indexing("combinedcontainer").
      sd(selfdir + "test.sd").
      storage(StorageCluster.new("search", 4).distribution_bits(16)))

    start

    @container = @vespa.container.values.first
    @api = @vespa.document_api_v1
  end

  def test_get_visit_throughput
    feed({ :template => @document_template, :count => @document_count })
    run_get_visiting_benchmarks
  end

  def test_process_visit_throughput
    feed({ :template => @document_template, :count => @document_count })
    run_process_visiting_benchmarks
  end

  def visit(uri:, method: 'GET', body: '')
    endpoint = "#{@tls_env.tls_enabled? ? "https" : "http"}://localhost:#{@container.http_port}"
    if @tls_env.tls_enabled?
      args = "--key #{@tls_env.private_key_file} --cert #{@tls_env.certificate_file} --cacert #{@tls_env.ca_certificates_file}"
    else
      args = ""
    end
    documents = 0
    continuation = ''
    doom = Time.now.to_f + 39
    while Time.now.to_f < doom
      command="curl -s -X #{method} #{args} '#{endpoint}#{uri}#{continuation}' -d '#{body}' | jq '{ path, continuation, documentCount, message }'"
      json = JSON.parse(@container.execute(command))
      return json['message'] if json['message']
      if json['documentCount']
        documents += json['documentCount']
      else
        return "No documentCount in response"
      end
      if json['continuation']
        continuation = "&continuation=#{json['continuation']}"
      else
        break
      end
    end
    documents
  end
  
  def run_get_visiting_benchmarks
    { "1-percent" => @selection_1p, "100-percent" => @selection_100p }.each do |s_name, s_value|
      [1, 100].each do |concurrency|
        [1, 8, 64].each do |slices|
          parameters = { :timeout => "40s", :cluster => "search", :selection => s_value, :concurrency => concurrency, :slices => slices }
          fillers = [parameter_filler('concurrency', concurrency)]
          thread_pool = Concurrent::FixedThreadPool.new(slices)
          documents = Concurrent::Array.new

          benchmark_operations(legend: "chunked-#{s_name}-#{concurrency}c-#{slices}s") do |api|
            slices.times do |sliceId|
              thread_pool.post do
                documents[sliceId] = visit(uri: to_uri(parameters: parameters.merge({ :wantedDocumentCount => 1024, :sliceId => sliceId })))
              end
            end
            thread_pool.shutdown
            raise "Failed to complete tasks" unless thread_pool.wait_for_termination(60)
            documents.each { |d| raise d unless d.is_a? Integer }
            documents.sum
          end

          documents.clear
          benchmark_operations(legend: "streamed-#{s_name}-#{concurrency}c-#{slices}s")]) do |api|
            slices.times do |sliceId|
              thread_pool.post do
                documents[sliceId] = visit(uri: to_uri(parameters: parameters.merge({ :stream => true, :sliceId => sliceId })))
              end
            end
            thread_pool.shutdown
            raise "Failed to complete tasks" unless thread_pool.wait_for_termination(60)
            documents.each { |d| raise d unless d.is_a? Integer }
            documents.sum
          end
        end
      end
    end
  end

  def run_process_visiting_benchmarks
    { "1-percent" => @selection_1p, "100-percent" => @selection_100p }.each do |s_name, s_value|
      parameters = { :timeChunk => "40s", :cluster => "search", :selection => s_value }

      benchmark_operations(legend: "refeed-#{s_name}") do |api|
        visit(uri: to_uri(parameters: parameters.merge({ :destinationCluster => "search" })), method: 'POST')
      end

      benchmark_operations(legend: "update-#{s_name}") do |api|
        visit(uri: to_uri(parameters: parameters, sub_path: "test/test/docid/"), method: 'PUT', body: @document_update)
      end

      benchmark_operations(legend: "delete-#{s_name}") do |api|
        visit(uri: to_uri(parameters: parameters), method: 'DELETE')
      end
    end
  end

  def benchmark_operations(legend:)
    profiler_start
    start_seconds = Time.now.to_f
    document_count = yield(@api)
    time_used = Time.now.to_f - start_seconds
    puts "#{document_count} documents visited in #{time_used} seconds"
    fillers = [parameter_filler('legend', legend), metric_filler('throughput', document_count / time_used)]
    profiler_report(legend)
    write_report(fillers)
  end

  def to_uri(sub_path: '', parameters: )
    "/document/v1/#{sub_path}?#{parameters.map { |k, v| "#{ERB::Util.url_encode(k.to_s)}=#{ERB::Util.url_encode(v)}" } .join("&")}"
  end

end
