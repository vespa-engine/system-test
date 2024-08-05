# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'


class TwoPhaseRankingTest < PerformanceTest

  SELECTION = "selection"
  BODY_POSITIONS = "body_positions"
  BODY_TERMS = "body_terms"
  TITLE_POSITIONS = "title_positions"
  TITLE_TERMS = "title_terms"
  RANK_PROFILE = "rank_profile"
  BASIC_TWO_PHASE = "basic_two_phase"
  FBENCH_RUNTIME = 20
  
  def initialize(*args)
    super(*args)
  end
  
  def setup
    super
    set_owner("geirst")
  end
  
  def create_doc(num_docs, path)
    container = vespa.container.values.first
    container.execute( "g++ -std=c++0x #{selfdir}doc_generator.cpp -o #{selfdir}doc_generator")
    container.execute("#{selfdir}doc_generator #{num_docs} > #{path}")
    return path
  end
  
  def test_two_phase_ranking
    set_description("Test search performance when doing two-phase ranking")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    @container = vespa.container.values.first
    docs_file_10K = create_doc(10000, "#{dirs.tmpdir}two_phase_ranking.10K.docs.json")  
    docs_file_1M = create_doc(1000000, "#{dirs.tmpdir}two_phase_ranking.1M.docs.json")   
    docs_file = docs_file_1M
    run_feeder(docs_file, [], {localfile: true})
    vespa.search["search"].first.trigger_flush

    # warmup
    run_fbench_helper(100, 8, 8, BASIC_TWO_PHASE, false)

    [100, 50, 20, 10, 5, 2, 1].each do |selection|
      run_fbench_helper(selection, 4, 4, BASIC_TWO_PHASE)
    end

    [1, 4, 16, 64].each do |body_positions|
      run_fbench_helper(20, body_positions, 4, BASIC_TWO_PHASE)
    end

    [1, 4, 16, 64].each do |body_terms|
      run_fbench_helper(20, 4, body_terms, BASIC_TWO_PHASE)
    end
  end

  def run_fbench_helper(selection, body_positions, body_terms, rank_profile, run_profiler=true)
    query_file = write_query_file(selection, body_positions, body_terms, 1, 1)
    fillers = [parameter_filler(SELECTION, selection),
               parameter_filler(BODY_POSITIONS, body_positions),
               parameter_filler(BODY_TERMS, body_terms),
               parameter_filler(TITLE_POSITIONS, 1),
               parameter_filler(TITLE_TERMS, 1),
               parameter_filler(RANK_PROFILE, rank_profile)]
    profiler_start if run_profiler
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_RUNTIME, :clients => 1, :append_str => "&ranking=#{rank_profile}"},
                fillers)
    profiler_report(get_label(selection, body_positions, body_terms, rank_profile)) if run_profiler
  end

  def get_label(selection, body_positions, body_terms, rank_profile)
    "#{SELECTION}-#{selection}.#{BODY_POSITIONS}-#{body_positions}.#{BODY_TERMS}-#{body_terms}.#{RANK_PROFILE}-#{rank_profile}"
  end

  def write_query_file(selection, body_positions, body_terms, title_positions, title_terms)
    file_name = dirs.tmpdir + "queries." + get_label(selection, body_positions, body_terms, "nil") + ".txt"
    file = File.open(file_name, "w")
    file.write(gen_query(selection, body_positions, body_terms, title_positions, title_terms) + "\n")
    file.close
    @container.copy(file_name, File.dirname(file_name))
    return file_name
  end

  def gen_query(selection, body_positions, body_terms, title_positions, title_terms)
    selection_str = "selection:#{selection}"
    title_str = gen_terms("title", title_positions, title_terms)
    body_str = gen_terms("body", body_positions, body_terms)
    "/search/?query=#{selection_str}+RANK+#{title_str}+#{body_str}&type=adv&nocache"
  end

  def gen_terms(field, term, num_terms)
      Array.new(num_terms, "#{field}:#{term}").join('+')
  end

  def teardown
    super
  end

end