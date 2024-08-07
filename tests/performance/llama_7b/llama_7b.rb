# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class Llama7BPerformanceTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("lesters")
  end

  def teardown
    super
  end

  def timeout_seconds
    900
  end

  def test_llama_7b_inference
    set_description("Test inference of a local llm - 7B size")

    @queries_file_name = dirs.tmpdir + "/queries.txt"

    generate_queries
    deploy_app
    copy_query_file

    run_queries
  end

  def generate_queries
    prompts = [
      "Write a short story about a time-traveling detective who must solve a mystery that spans multiple centuries.",
      "Explain the concept of blockchain technology and its implications for data security in layman's terms.",
      "Discuss the socio-economic impacts of the Industrial Revolution in 19th century Europe.",
      "Describe a future where humans have colonized Mars, focusing on daily life and societal structure.",
      "Analyze the statement 'If a tree falls in a forest and no one is around to hear it, does it make a sound?' from both a philosophical and a physics perspective.",
      "Translate the following sentence into French: 'The quick brown fox jumps over the lazy dog.'",
      "Explain what the following Python code does: `print([x for x in range(10) if x % 2 == 0])`.",
      "Provide general guidelines for maintaining a healthy lifestyle to reduce the risk of developing heart disease.",
      "Create a detailed description of a fictional planet, including its ecosystem, dominant species, and technology level.",
      "Discuss the impact of social media on interpersonal communication in the 21st century.",
    ]
    puts "generate_queries"
    file = File.open(@queries_file_name, "w")

    prompts.each do |prompt|
      query = URI.encode_www_form_component(prompt)
      file.write("/search/?query=#{query}\n")
    end

    file.close
  end

  def deploy_app
    deploy(selfdir + "/app")
    puts "Starting application: this might take a while due to download of LLM..."
    start(600)
    puts "Application started."
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
  end

  def run_queries
    num_clients = 1
    puts "run_fbench_helper(#{num_clients.to_s})"
    fillers = [
      parameter_filler("clients", num_clients.to_s),
    ]
    tokens_to_generate = 100
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => 120, :clients => num_clients, :append_str => "&searchChain=llm&format=sse&llm.npredict=#{tokens_to_generate}"},
                fillers)
    profiler_report("rank_profile-#{num_clients.to_s}")
  end

  def copy_query_file
    @container.copy(@queries_file_name, File.dirname(@queries_file_name))
  end

end

