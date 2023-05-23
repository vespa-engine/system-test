require 'performance_test'
require 'app_generator/search_app'
require 'environment'


class EmbeddingPerfTest < PerformanceTest

  def setup
    set_owner("bjorncs")
  end

  def test_huggingface
    set_description('Benchmark feed throughput with paraphrase-multilingual-MiniLM-L12-v2 ONNX model')
    deploy(selfdir + "app")
    start
    feed_file = 'miracl-te-docs.100k.json.gz'
    remote_file = "https://data.vespa.oath.cloud/tests/performance/#{feed_file}"
    local_file =  dirs.tmpdir + feed_file
    cmd = "wget -O'#{local_file}' '#{remote_file}'"
    puts "Running command #{cmd}"
    result = `#{cmd}`
    puts "Result: #{result}"
    run_feeder(local_file, [])
  end
end
