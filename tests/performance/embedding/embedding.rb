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
    file = download_file_from_s3('miracl-te-docs.100k.json.gz', vespa.adminserver)
    run_feeder(file, [], {:localfile => true})
  end
end
