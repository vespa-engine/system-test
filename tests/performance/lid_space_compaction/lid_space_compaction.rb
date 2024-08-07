# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'environment'

class LidSpaceCompactionPerfTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def get_app(lid_bloat_factor = 0.2)
    SearchApp.new.cluster(SearchCluster.new.sd(selfdir + "test.sd").
                          allowed_lid_bloat(10).
			  allowed_lid_bloat_factor(lid_bloat_factor).
                          config(ConfigOverride.new("vespa.config.search.core.proton").
                                 add("maintenancejobs", ConfigValues.new.
                                     add("maxoutstandingmoveops", 100)).
                                 add("summary", ConfigValues.new.
                                     add("write", ConfigValues.new.
                                         add("io", "NORMAL"))).
                                 add("lidspacecompaction", ConfigValues.new.
                                     add("interval", 2.0)))).
                          search_dir(selfdir + "app")
  end

  def get_fillers(start_time, end_time)
    run_time = (end_time - start_time).to_f
    throughput = @num_docs_to_compact / run_time
    puts "RESULT: compaction.runtime=#{run_time}, compaction.count=#{@num_docs_to_compact}, compaction.throughput=#{throughput}"
    [metric_filler("compaction.runtime", run_time),
     metric_filler("compaction.count", @num_docs_to_compact),
     metric_filler("compaction.throughput", throughput),
     parameter_filler("legend", "compaction_performance")]
  end

  def create_query_file(query_file)
    f = File.new(query_file, "w")

    for key in 0..19999
      f.puts("/search/?query=key:#{key.to_s}&sorting=id&hits=1000")
    end
    f.close
    return File.absolute_path(query_file)
  end

  def warmup(container, queries, summary)
    container.execute("vespa-fbench-split-file -p #{queries}.%02d 20 #{queries}")
    run_fbench2(container, "#{queries}.%02d",
                { :times_reuse_query_files => 0, :runtime => 30, :clients => 20,
                  :append_str => "&summary=#{summary}",
                  :result_file => "#{dirs.tmpdir}/result.warmup.#{summary}.txt.%02d"},
                [ parameter_filler("legend", "idle-#{summary}") ])
    container.execute("cat #{dirs.tmpdir}/result.warmup.#{summary}.txt.* > #{dirs.tmpdir}/result.warmup.#{summary}.txt")
  end

  def verify_summaries(container, queries, summary)
    run_fbench2(container, queries,
                { :runtime => 30, :clients => 4, :append_str => "&summary=#{summary}",
                  :result_file => "#{dirs.tmpdir}/result.compact.#{summary}.%d.txt"},
                [ parameter_filler("legend", "compact_lidspace") ])
    container.execute("#{@tmp_bin_dir}/verify_results #{dirs.tmpdir}/result.warmup.#{summary}.txt #{dirs.tmpdir}/result.compact.#{summary}.0.txt", {:exceptiononfailure => false})
    container.execute("#{@tmp_bin_dir}/verify_results #{dirs.tmpdir}/result.warmup.#{summary}.txt #{dirs.tmpdir}/result.compact.#{summary}.1.txt", {:exceptiononfailure => false})
    container.execute("#{@tmp_bin_dir}/verify_results #{dirs.tmpdir}/result.warmup.#{summary}.txt #{dirs.tmpdir}/result.compact.#{summary}.2.txt", {:exceptiononfailure => false})
    container.execute("#{@tmp_bin_dir}/verify_results #{dirs.tmpdir}/result.warmup.#{summary}.txt #{dirs.tmpdir}/result.compact.#{summary}.3.txt", {:exceptiononfailure => false})
  end

  def test_lid_space_compaction
    set_description("Test the speed of lid space compaction after feeding 20M docs (average 500 bytes) and 10M random removes")
    @num_docs = 20000000
    @num_docs_to_compact = @num_docs / 2
    deploy_app(get_app(2.0)) # no compaction will happen
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    @tmp_bin_dir = container.create_tmp_bin_dir
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@tmp_bin_dir}/verify_results #{selfdir}/verify_results.cpp")
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@tmp_bin_dir}/docs #{selfdir}/docs.cpp")
    queries = create_query_file("query.txt")
    container.copy(queries, "#{dirs.tmpdir}")
    queries = "#{dirs.tmpdir}/query.txt"
    start
    container.logctl("searchnode:proton.server.searchview", "debug=on")
    container.execute("#{@tmp_bin_dir}/docs put #{@num_docs} | vespa-feeder")
    assert_hitcount("sddocname:test", @num_docs)

    container.execute("#{@tmp_bin_dir}/docs remove #{@num_docs_to_compact} | vespa-feeder")
    assert_hitcount("sddocname:test", @num_docs_to_compact)
    vespa.search["search"].first.trigger_flush # make sure document store is compacted

    warmup(container, queries, "short")
    warmup(container, queries, "slow")

    profiler_start
    deploy_app(get_app(0.1)) # trigger compaction
    start_time = Time.now
    verify_summaries(container, queries, "short")
    verify_summaries(container, queries, "slow")

    wait_for_log_matches(/.lidspace\.compaction\.complete/, 1, 3600*5)
    end_time = Time.now
    write_report(get_fillers(start_time, end_time))
    profiler_report
  end

  def teardown
    super
  end

end
