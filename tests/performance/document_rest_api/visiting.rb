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
    @selection_1p = 10.times.map { |i| "test.number % 100 == #{i}" }
    @selection_100p = [ 'true' ]
    @visit_seconds = 40

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

  def visit(selections:, parameters:, sub_path:, method:, body:)
    endpoint = "#{@tls_env.tls_enabled? ? "https" : "http"}://localhost:#{@container.http_port}"
    if @tls_env.tls_enabled?
      args = "--key #{@tls_env.private_key_file} --cert #{@tls_env.certificate_file} --cacert #{@tls_env.ca_certificates_file}"
    else
      args = ""
    end
    documents = 0
    doom = Time.now.to_f + @visit_seconds - 1
    selections.each do |selection|
      parameters[:selection] = selection
      while Time.now.to_f < doom
        uri = to_uri(sub_path: sub_path, parameters: parameters)
        command="curl -s -X #{method} #{args} '#{endpoint}#{uri}' -d '#{body}' | jq '{ continuation, documentCount, message }'"
        json = JSON.parse(@container.execute(command))
        return json['message'] if json['message']
        if json['documentCount']
          documents += json['documentCount']
        else
          return "No documentCount in response"
        end
        if json['continuation']
          parameters[:continuation] = json['continuation']
        else
          parameters.delete(:continuation)
          break
        end
      end
    end
    documents
  end
  
  def run_get_visiting_benchmarks
    { "1-percent" => @selection_1p, "100-percent" => @selection_100p }.each do |s_name, s_value|
      [[1, 1], [1, 16], [16, 1], [16, 16], [64, 1]].each do |concurrency, slices|
        parameters = { :timeout => "#{@visit_seconds}s", :cluster => "search", :concurrency => concurrency, :slices => slices }

        benchmark_operations(legend: "chunked-#{s_name}-#{concurrency}c-#{slices}s", selections: s_value,
                             parameters: parameters.merge({ :wantedDocumentCount => 1024 }))

        benchmark_operations(legend: "streamed-#{s_name}-#{concurrency}c-#{slices}s", selections: s_value,
                             parameters: parameters.merge({ :stream => true }))
      end
    end
  end

  def run_process_visiting_benchmarks
    { "1-percent" => @selection_1p, "100-percent" => @selection_100p }.each do |s_name, s_value|
      [1, 16].each do |slices|
        parameters = { :timeChunk => "#{@visit_seconds}s", :cluster => "search", :slices => slices }
        benchmark_operations(legend: "refeed-#{s_name}-#{slices}s", selections: s_value,
                             parameters: parameters.merge({ :destinationCluster => "search" }), method: 'POST')

        benchmark_operations(legend: "update-#{s_name}-#{slices}s", selections: s_value,
                             parameters: parameters, sub_path: "test/test/docid/", method: 'PUT', body: @document_update)

        benchmark_operations(legend: "delete-#{s_name}-#{slices}s", selections: s_value,
                             parameters: parameters, method: 'DELETE')
      end
    end
  end

  def benchmark_operations(legend:, selections:, parameters:, sub_path: '', method: 'GET', body: '')
    thread_pool = Concurrent::FixedThreadPool.new(parameters[:slices])
    documents = Concurrent::Array.new
    profiler_start
    start_seconds = Time.now.to_f
    parameters[:slices].times do |sliceId|
      thread_pool.post do
        begin
          documents[sliceId] = visit(selections: selections, parameters: parameters.merge({ :sliceId => sliceId }),
                                     sub_path: sub_path, method: method, body: body)
        rescue Exception => e
          puts "Exception for slice #{sliceId}:"
          puts e.message
          puts e.backtrace.inspect
          documents[sliceId] = e
        end
      end
    end
    thread_pool.shutdown
    raise "Failed to complete tasks" unless thread_pool.wait_for_termination(60)
    documents.each { |d| raise d unless d.is_a? Integer }
    document_count = documents.sum
    time_used = Time.now.to_f - start_seconds
    puts "#{document_count} documents visited in #{time_used} seconds"
    fillers = [parameter_filler('legend', legend), metric_filler('throughput', document_count / time_used)]
    write_report(fillers)
    profiler_report(legend)
  end

  def to_uri(sub_path:, parameters:)
    "/document/v1/#{sub_path}?#{parameters.map { |k, v| "#{ERB::Util.url_encode(k.to_s)}=#{ERB::Util.url_encode(v)}" } .join("&")}"
  end

end
