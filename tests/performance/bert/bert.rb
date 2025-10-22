# Copyright Vespa.ai. All rights reserved
require 'performance_test'
require 'performance/fbench'
require 'remote_file_utils'

class BERTPerformanceTest < PerformanceTest

  def setup
    set_owner("glebashnik")
    @valgrind = false
    @node = @vespa.nodeproxies.first[1]
    override_environment_setting(@node, "VESPA_CONFIGSERVER_JVMARGS", "-Xms12g -Xmx12g")
  end

  def test_single_evaluation_bert_performance
    set_description("Performance test of BERT model evaluation - one evaluation")

    @queries_file_name = "queries.txt"
    @deploy_dir = dirs.tmpdir + "bert_tmp"

    download_model
    deploy_and_feed

    run_queries("vespabert", 1)
    run_queries("onnxbert", 1)
    run_queries("globalonnxbert", 1)

    verify_expected_result("vespabert")
    verify_expected_result("onnxbert")
    verify_expected_result("globalonnxbert")
  end

  def download_model
    puts "Building application package in #{@deploy_dir}"
    system("mkdir -p #{@deploy_dir}") || raise
    system("cp -a #{selfdir}/app #{@deploy_dir}") || raise
    RemoteFileUtils.download(URI("https://data.vespa-cloud.com/tests/performance/bert/bertsquad8.onnx"), "#{@deploy_dir}/app/models/bertsquad8.onnx")
  end

  def deploy_and_feed
    deploy("#{@deploy_dir}/app", nil, :timeout =>  1000)
    start
    feed_and_wait_for_docs("bert", 1, :file => selfdir + "feed.json")
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
  end

  def run_queries(rank_profile, clients)
    copy_query_file
    fillers = [
        parameter_filler("rank_profile", rank_profile),
        parameter_filler("clients", clients)
    ]
    profiler_start
    run_fbench2(@container,
                dirs.tmpdir + @queries_file_name,
                {:runtime => 60, :clients => clients, :append_str => "&ranking=#{rank_profile}&timeout=300"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}.clients-#{clients}")
  end

  def copy_query_file
    @container.copy(selfdir + @queries_file_name, dirs.tmpdir)
  end

  def verify_expected_result(rank_profile)
    result = search_with_timeout(300, "query=sddocname:bert&hits=1&ranking=#{rank_profile}")
    result.hit.each { |hit|
      expected = hit.field["expected"].to_f
      result_from_ranking = hit.field["relevancy"].to_f
      puts "Expected: " + expected.to_s + " Result: " + result_from_ranking.to_s
      assert_equals(expected, result_from_ranking)
    }
  end

  def assert_equals(a, b)
    assert((a-b).abs < 0.001)
  end

  def teardown
    override_environment_setting(@node, "VESPA_CONFIGSERVER_JVMARGS", nil) if @node
    stop
  end

end
