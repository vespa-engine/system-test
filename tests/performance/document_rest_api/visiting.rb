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
    @document_count = 1 << 22
    @document_template = '{ "put": "id:test:test::$seq()", "fields": { "text": "$words(5)", "number": $ints(1, 100) } }'
    @document_update = '{ "fields": { "number": { "increment": 100 } } }'
    @selection_1p = 'test.number % 100 == 0'
    @selection_100p = 'test.number >= 0'

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
    doom = Time.now.to_f + 30
    while Time.now.to_f < doom
      command="curl -s -X #{method} #{args} '#{endpoint}#{uri}#{continuation}' -d '#{body}' | tee >(head -c 1000 >&2) | jq '{ continuation, documentCount, message }'"
      out, err = @container.execute(command)
      json = JSON.parse(out)
      puts "0 documents visited, HTTP response first 1000 bytes: #{err}"
      return json['message'] if json['message']
      documents += json['documentCount'] if json['documentCount']
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
        parameters = { :timeout => "40s", :cluster => "search", :selection => s_value, :concurrency => concurrency }
        fillers = [parameter_filler('concurrency', concurrency)]

        benchmark_operations(legend: 'chunked', filter: s_name, fillers: fillers) do |api|
          visit(uri: to_uri(parameters: parameters.merge({ :wantedDocumentCount => 1024 })))
        end

        [1, 8, 64].each do |slices|
          my_parameters = parameters.merge({ :stream => true, :slices => slices })
          thread_pool = Concurrent::FixedThreadPool.new(slices)
          documents = Concurrent::Array.new

          benchmark_operations(legend: 'streamed', filter: s_name, fillers: fillers + [parameter_filler('slices', slices)]) do |api|
            slices.times do |sliceId|
              thread_pool.post do
                documents[sliceId] = visit(uri: to_uri(parameters: my_parameters.merge({ :sliceId => sliceId })))
              end
            end
            thread_pool.shutdown
            thread_pool.wait_for_termination
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

      benchmark_operations(legend: 'refeed', filter: s_name) do |api|
        visit(uri: to_uri(parameters: parameters.merge({ :destinationCluster => "search" })), method: 'POST')
      end

      benchmark_operations(legend: 'update', filter: s_name) do |api|
        visit(uri: to_uri(parameters: parameters, sub_path: "test/test/docid/"), method: 'PUT', body: @document_update)
      end

      benchmark_operations(legend: 'delete', filter: s_name) do |api|
        visit(uri: to_uri(parameters: parameters), method: 'DELETE')
      end
    end
  end

  def benchmark_operations(legend:, filter:, fillers: [])
    profiler_start
    start_seconds = Time.now.to_f
    document_count = yield(@api)
    puts "#{document_count} documents visited in total"
    fillers = fillers + [parameter_filler('legend', legend),
                         parameter_filler('filter', filter),
                         metric_filler('throughput', document_count / (Time.now.to_f - start_seconds))]
    profiler_report(legend + '-' + filter)
    write_report(fillers)
  end

  def to_uri(sub_path: '', parameters: )
    "/document/v1/#{sub_path}?#{parameters.map { |k, v| "#{ERB::Util.url_encode(k.to_s)}=#{ERB::Util.url_encode(v)}" } .join("&")}"
  end

end
