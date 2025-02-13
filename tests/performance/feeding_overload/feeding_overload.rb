require 'performance_test'
require 'app_generator/search_app'
require 'environment'


class FeedingOverloadPerfTest < PerformanceTest

  def setup
    set_owner("bjorncs")
  end

  def test_feeding_latency_under_overload
    set_description('Benchmark feeding latency under overload (using app with HF embedder)')
    deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            search(Searching.new).
            documentapi(ContainerDocumentApi.new).
            docproc(DocumentProcessing.new).
            jvmoptions('-Xms512m -Xmx512m').
            component(
              Component.new('hf').
              type('hugging-face-embedder').
              param('transformer-model', '', {'url' => 'https://data.vespa-cloud.com/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.onnx'}).
              param('tokenizer-model', '', {'url' => 'https://data.vespa-cloud.com/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.tokenizer.json'}).
              param('transformer-output', 'output_0'))).
        sd(selfdir + 'app/schemas/doc.sd'))
    start
    feed_file = 'miracl-te-docs.100k.json.gz'
    remote_file = "https://data.vespa-cloud.com/tests/performance/#{feed_file}"
    local_file =  dirs.tmpdir + feed_file
    cmd = "wget -O'#{local_file}' '#{remote_file}'"
    puts "Running command #{cmd}"
    result = `#{cmd}`
    puts "Result: #{result}"
    warmup_file = dirs.tmpdir + 'miracl-warmup.json'
    result = `gunzip -c #{local_file} | jq '.[0:10000]' > #{warmup_file}`
    puts "Result: #{result}"
    # Use vespa-feed-client for to measure feeding latency end-to-end
    feeder_options = { :client => :vespa_feed_client,
                       :numconnections => 128,
                       :max_streams_per_connection => 128,
                       :compression => "none",
                       :silent => true,
                       :route => 'default/chain.indexing null/default',
                       :disable_tls => false }
    run_feeder(warmup_file, [], feeder_options.merge({:warmup => true}))
    run_feeder(local_file, [], feeder_options)
  end
end
