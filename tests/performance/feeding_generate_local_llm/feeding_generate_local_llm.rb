require 'performance_test'
require 'app_generator/search_app'
require 'environment'

class FeedingGenerateLocalLLMPerformanceTests < PerformanceTest
  def setup
    set_owner('glebashnik')
  end

  def timeout_seconds
    2400
  end

  def test_feeding_generate_local_llm
    set_description("Performance test for feeding with text generation using local LLM.")

    deploy(selfdir + "app")
    puts "Starting application: this might take a while due to download of LLM..."
    start(900)
    puts "Application started."

    node = (vespa.qrserver["0"] or vespa.container.values.first)
    node.execute('tail -n 50 /proc/cpuinfo')
    node.execute('printenv')

    feed_file = (selfdir + "data/feed.jsonl")
    feeder_options = { :client => :vespa_feed_client, :timeout => 600 }
    run_feeder(feed_file, [], feeder_options)
  end
end
