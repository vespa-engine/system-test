# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class SparseTensorWandPerformanceTest < PerformanceTest

  NUM_DOCS = 500_000
  NUM_QUERIES = 10_000
  TARGET_HITS = [100, 1000]
  SEARCH_THREADS = [1, 4]

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("arnej")
  end

  def test_sparse_tensor_wand
    set_description("Test performance of the sparseTensorWand query operator, compared with " +
                    "wand over a weighted set and brute force dot product in ranking")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    @container = (vespa.qrserver["0"] or vespa.container.values.first)

    feed_docs
    write_query_files
    check_same_top_hit

    TARGET_HITS.each do |target_hits|
      ["stw", "stw_fast", "wand"].each do |variant|
        SEARCH_THREADS.each do |threads|
          run_benchmark(variant, target_hits, threads)
        end
      end
    end
    SEARCH_THREADS.each do |threads|
      run_benchmark("bruteforce", 0, threads)
    end
  end

  def copy_generator(node)
    node.copy(selfdir + "gen_data.rb", dirs.tmpdir)
    dirs.tmpdir + "gen_data.rb"
  end

  def feed_docs
    node = vespa.adminserver
    generator = copy_generator(node)
    (exitcode, output) = execute(node, "ruby #{generator} docs #{NUM_DOCS} | vespa-feed-perf")
    assert_equal(0, exitcode)
    wait_for_hitcount("sddocname:test", NUM_DOCS, 60)
    searchnode = vespa.search["search"].first
    searchnode.trigger_flush
  end

  def query_file(variant, target_hits)
    dirs.tmpdir + "queries-#{variant}-#{target_hits}.txt"
  end

  def write_query_files
    generator = copy_generator(@container)
    queries = [["bruteforce", 0]]
    TARGET_HITS.each do |target_hits|
      ["stw", "stw_fast", "wand"].each { |variant| queries << [variant, target_hits] }
    end
    queries.each do |variant, target_hits|
      file = query_file(variant, target_hits)
      (exitcode, output) = execute(@container, "ruby #{generator} queries #{variant} #{target_hits} #{NUM_QUERIES} > #{file}")
      assert_equal(0, exitcode)
    end
  end

  def first_query(variant, target_hits)
    url = @container.execute("head -1 #{query_file(variant, target_hits)}").strip
    url.sub("/search/?", "") + "&hits=1&presentation.summary=minimal"
  end

  # All variants compute the same dot product, and the top score should thus be the same.
  # Several documents may share the top score, so the ids are not compared.
  def check_same_top_hit
    expected = search(first_query("bruteforce", 0))
    assert_equal(1, expected.hit.size)
    exp_score = expected.hit[0].field['relevancy'].to_f
    puts "Top hit for first query: id=#{expected.hit[0].field['id']}, score=#{exp_score}"
    TARGET_HITS.each do |target_hits|
      ["stw", "stw_fast", "wand"].each do |variant|
        result = search(first_query(variant, target_hits))
        assert_equal(1, result.hit.size, "#{variant} with targetHits #{target_hits}")
        assert_in_delta(exp_score, result.hit[0].field['relevancy'].to_f, 1e-3,
                        "#{variant} with targetHits #{target_hits}")
      end
    end
  end

  def run_benchmark(variant, target_hits, threads)
    legend = "#{variant}-targethits-#{target_hits}-threads-#{threads}"
    puts "Running fbench: #{legend}"
    system_fbench = Perf::System.new(@container)
    system_fbench.start
    fbench = Perf::Fbench.new(@container, @container.name, @container.http_port)
    fbench.max_line_size = 10000
    fbench.single_query_file = true
    fbench.runtime = 30
    fbench.clients = 1
    fbench.ignore_first = 10
    fbench.append_str = "&hits=10&presentation.summary=minimal&timeout=10s" +
                        "&ranking.matching.numThreadsPerSearch=#{threads}"
    profiler_start
    fbench.query(query_file(variant, target_hits))
    system_fbench.end
    profiler_report(legend)
    write_report([fbench.fill, system_fbench.fill,
                  parameter_filler("legend", legend),
                  parameter_filler("variant", variant),
                  parameter_filler("targethits", target_hits),
                  parameter_filler("threads", threads)])
  end

end
