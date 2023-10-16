# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
#
require 'performance_test'
require 'app_generator/search_app'
require 'environment'

class FeedingAndRecoveryTest < PerformanceTest

  def timeout_seconds
    # Slightly more than four hours
    15000
  end

  def prepare
    super
    @statsdir = @dirs.resultoutput + 'stats/'
    `mkdir #{@statsdir}`
  end

  #----------------------------------------------------------------------------
  # wrapper classes to set parameters needed to run small or full test
  #----------------------------------------------------------------------------
  class SmallParams
    def feed0_docs
      100000
    end
    def feed1_docs
      750000
    end
    def fail_at
      250000
    end
    def replace_at
      500000
    end
    def profile_interval
      60
    end
  end

  class FullParams
    def feed0_docs
      10000000
    end
    def feed1_docs
      10000000
    end
    def fail_at
      13000000
    end
    def replace_at
      16000000
    end
    def profile_interval
      600
    end
  end

  #----------------------------------------------------------------------------
  # simple signal class used to tell threads to stop and keep track of time
  #----------------------------------------------------------------------------
  class Signal
    def initialize
      @signal = false
      @start = Time.now.to_f
    end
    def send
      @signal = true
    end
    def check
      @signal
    end
    def get_time
      Time.now.to_f - @start
    end
    def wait(t)
      while !@signal && get_time < t
        sleep(1)
      end
      !@signal
    end
  end

  #----------------------------------------------------------------------------
  # code run by separate thread to dump stats (metrics, top and profiling)
  #----------------------------------------------------------------------------

  def dump_metrics(nodes, prefix, suffix)
    n = 1;
    nodes.each do |node|
      res = node.get_state_v1_metrics
      if !res.nil?
        File.open("#{@statsdir}#{prefix}#{n}_#{suffix}", 'w') do |f|
          f.write(JSON.pretty_generate(res))
        end
      end
      n += 1
    end
  end

  def dump_stats(signal, tick, name)
    time = 0
    while signal.wait(time + tick)
      time = signal.get_time
      n = 1;
      dump_metrics(@vespa.storage["search"].distributor.values, "#{name}_distributor", time.to_i)
      dump_metrics(@vespa.storage["search"].storage.values, "#{name}_storage", time.to_i)
      dump_metrics(@vespa.search["search"].searchnode.values, "#{name}_search", time.to_i)
      `top -b -n1 > #{@statsdir}#{name}_top_#{time.to_i} 2>&1`
    end
  end

  def profile_local(signal, tick, name, list)
    time = 0
    `opcontrol --shutdown`
    `opcontrol --reset`
    `opcontrol --start`
    while signal.wait(time + tick)
      time = signal.get_time
      `opcontrol --dump`
      list.each do |item|
        `opreport -l "#{item[0]}" -t 0.1 > #{@statsdir}#{name}_profile_#{item[1]}_#{time.to_i} 2>&1`
      end
      `opcontrol --shutdown`
      `opcontrol --reset`
      `opcontrol --start`
    end
  end

  def monitor(name, &block)
    signal = Signal.new
    dump_thread = Thread.new do
      begin
        dump_stats(signal, 63, name)
      rescue => ex
        puts "#{ex.backtrace}: #{ex.message} (#{ex.class})"
      end
    end
    # profile_thread = Thread.new do
    #   begin
    #     profile_local(signal, @test_params.profile_interval, name, [["#{Environment.instance.vespa_home}/sbin64/vespa-proton-bin", "search"],
    #                                                                 ["#{Environment.instance.vespa_home}/sbin64/vespa-storaged-bin", "storage"],
    #                                                                 ["#{Environment.instance.vespa_home}/sbin64/vespa-distributord-bin", "distributor"]])
    #   rescue => ex
    #     puts "#{ex.backtrace}: #{ex.message} (#{ex.class})"
    #   end
    # end
    block.call
    signal.send
    # profile_thread.join
    dump_thread.join
  end

  #----------------------------------------------------------------------------

  def get_base_app(parts)
    SearchApp.new.monitoring("name", "60").
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms16g -Xmx16g').
                search(Searching.new).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing("combinedcontainer").
      config(ConfigOverride.new("vespa.config.content.core.stor-distributormanager").
             add("garbagecollection",
                 ConfigValues.new.add(ConfigValue.new("interval", 0)))).
      cluster(SearchCluster.new.
              sd(selfdir+"genfeed.sd").
              tune_searchnode({ :summary => {:store => {:logstore => { :maxfilesize => 160000000,
                                                                       :chunk => {:compression => {:level => 3 }}
                                                                     } } } }).
              num_parts(parts).
              redundancy(2).
              ready_copies(2))
  end

  def get_elastic_app(nodes)
    get_base_app(nodes)
  end

  def setup
    super
    set_owner("havardpe")

    # We dont want to run a global profiler for the whole tests. This is a long running test and
    # in the perf case, it segfaults on the files produced in this test.
    profiler_stop
  end

  def each_node(&block)
    @vespa.nodeproxies.values.each do |node|
      block.call(node)
    end
  end

  def profile(list, &block)
    block.call
  end

  def run_elastic_feeding_benchmark(nodes, fillers = [], &block)
    deploy_app(get_elastic_app(nodes))
    start
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    tmp_bin_dir = container.create_tmp_bin_dir
    @data_generator = "#{tmp_bin_dir}/docs"
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@data_generator} #{selfdir}/docs.cpp")

    profile(["#{Environment.instance.vespa_home}/sbin64/vespa-proton-bin",
             "#{Environment.instance.vespa_home}/sbin64/vespa-storaged-bin",
             "#{Environment.instance.vespa_home}/sbin64/vespa-distributord-bin"]) do
      run_stream_feeder("#{@data_generator} feed0 #{@test_params.feed0_docs} 100 100",
                 [parameter_filler("tag", "feeding"),
                  parameter_filler("cluster_setup", "elastic_#{nodes}")] + fillers,
                 :timeout => 3600,
                 :testdata_url => TESTDATA_URL)
    end
    # assert_hitcount("sddocname:genfeed&hits=0&nocache", @test_params.feed0_docs)
    wait_for_hitcount("sddocname:genfeed&hits=0&nocache", @test_params.feed0_docs)
    block.call
  end

  def stop_node
    vespa.search["search"].first.stop(true)
    vespa.storage["search"].distributor["0"].stop(30, false, true)
    vespa.storage["search"].storage["0"].wait_for_current_node_state('d', 64000)
    vespa.storage["search"].distributor["0"].wait_for_current_node_state('d', 64000)
  end

  def clean_node
    vespa.search["search"].first.execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/r0/c0")
  end

  def start_node
    vespa.search["search"].first.start
    vespa.storage["search"].distributor["0"].start
    vespa.storage["search"].storage["0"].wait_for_current_node_state('u', 64000)
    vespa.storage["search"].distributor["0"].wait_for_current_node_state('u', 64000)
  end

  def run_elastic_activation_benchmark
    assert_hitcount("sddocname:genfeed&hits=0&nocache", @test_params.feed0_docs)
    done = false
    thread = Thread.new do
      begin
        hits = search("sddocname:genfeed&hits=0&nocache").hitcount
      end while !done && hits == @test_params.feed0_docs
      glitch_count = 0
      start_glitch = Time.now.to_f
      while !done && hits != @test_params.feed0_docs
        glitch_count += 1
        hits = search("sddocname:genfeed&hits=0&nocache").hitcount
      end
      Thread.current["glitch_count"] = glitch_count
      Thread.current["glitch_time"] = Time.now.to_f - start_glitch
    end
    stop_node
    begin
      hits = search("sddocname:genfeed&hits=0&nocache").hitcount
    end while hits != @test_params.feed0_docs
    done = true
    thread.join
    count = thread["glitch_count"]
    time = count == 0 ? 0 : thread["glitch_time"]
    puts "#" * 80
    puts "# Activation glitch: #{time} (#{count} samples)"
    puts "#" * 80
    write_report([parameter_filler("tag", "activation"),
                  parameter_filler("activation", "activation"),
                  metric_filler("glitch", time)])
    # keep storage node down for recovery test
  end

  def run_elastic_recovery_benchmark
    # node already stopped by activation test
    clean_node
    moves = @test_params.feed0_docs / 2
    profile(["#{Environment.instance.vespa_home}/sbin64/vespa-proton-bin",
             "#{Environment.instance.vespa_home}/sbin64/vespa-storaged-bin",
             "#{Environment.instance.vespa_home}/sbin64/vespa-distributord-bin"]) do
      time = Time.now.to_f
      start_node
      begin
        vespa.storage["search"].wait_until_ready(64000)
      rescue Exception => e
        puts "wait_until_ready failed with exception: #{e}. Retrying once."
        # Temporary! Used to confirm if apparent DB sync issues are transient or stable.
        vespa.storage["search"].wait_until_ready(64000)
      end
      time = Time.now.to_f - time
      write_report([parameter_filler("tag", "recovery"),
                    parameter_filler("recovery", "recovery"),
                    metric_filler("throughput", moves / time)])
    end
    assert_hitcount("sddocname:genfeed&hits=0&nocache", @test_params.feed0_docs)
  end

  def collect_metrics(nodes, name)
    rate = 0
    node_cnt = 0
    nodes.each do |node|
      res = node.get_state_v1_metrics
      if !res.nil? && !res["metrics"].nil? && !res["metrics"]["values"].nil?
        res["metrics"]["values"].each do |m|
          if m['name'] == name
            rate += m["values"]["rate"]
            node_cnt += 1
          end
        end
      end
    end
    puts "### => rate of '#{name}': #{rate} (from #{node_cnt} nodes) <= ###"
    rate
  end

  def sample_metrics(signal, tick)
    samples = []
    Thread.current["samples"] = samples
    start = Time.now.to_f
    time = 0
    while !signal.check
      sleep(1)
      t = Time.now.to_f - start
      if t - time >= tick
        time = t
        proton_put_rate = collect_metrics(@vespa.search["search"].searchnode.values,
                                          'proton.doctypes.genfeed.feedmetrics.puts')
        distributor_put_rate = collect_metrics(@vespa.storage["search"].distributor.values,
                                               'vds.distributor.puts.sum.ok')
        sample = { 'time' => time,
          'external_rate' => distributor_put_rate,
          'internal_rate' => proton_put_rate - (distributor_put_rate * 2) }
        samples << sample
      end
    end
  end

  def simulate_failure(signal, down_docs, up_docs)
    while !signal.check && search("sddocname:genfeed&hits=0&nocache").hitcount < down_docs
      sleep(1)
    end
    puts "### => simulating node failure <= ###"
    stop_node
    clean_node
    while !signal.check && search("sddocname:genfeed&hits=0&nocache").hitcount < up_docs
      sleep(1)
    end
    puts "### => simulating node replacement <= ###"
    start_node
  end

  def run_elastic_feeding_and_recovery_benchmark(dps)
    assert_hitcount("sddocname:genfeed&hits=0&nocache", @test_params.feed0_docs)
    signal = Signal.new
    sample_thread = Thread.new do
      sample_metrics(signal, 63)
    end
    failure_thread = Thread.new do
      simulate_failure(signal, @test_params.fail_at, @test_params.replace_at)
    end

    feed_stream("#{@data_generator} feed1 #{@test_params.feed1_docs} 100 100", :timeout => 3600)
    failure_thread.join
    vespa.storage["search"].wait_until_ready(64000)

    signal.send
    sample_thread.join
    sample_thread["samples"].each do |s|
      write_report([parameter_filler("tag", "feeding_and_recovery"),
                    parameter_filler("source", "external"),
                    metric_filler("time", s["time"]),
                    metric_filler("throughput", s["external_rate"])])
      write_report([parameter_filler("tag", "feeding_and_recovery"),
                    parameter_filler("source", "internal"),
                    metric_filler("time", s["time"]),
                    metric_filler("throughput", s["internal_rate"])])
    end
  end

  class MetricSniffer
    def initialize(names)
      @metric_names = names
      @metrics = {}
    end
    def call(result)
      @metric_names.each do |name|
        @metrics[name] = result.metric(name)
      end
    end
    def get(name)
      @metrics[name]
    end
  end

  def test_feeding_and_recovery
    @test_params = has_active_sanitizers ? SmallParams.new : LargeParams.new
    sniffer = MetricSniffer.new(["feeder.throughput"])
    run_elastic_feeding_benchmark(3, [sniffer]) { stop }
    dps = (sniffer.get("feeder.throughput").to_i * 0.8).to_i
    assert(dps > 10)
    run_elastic_feeding_benchmark(4) {}
    run_elastic_activation_benchmark
    run_elastic_recovery_benchmark
    run_elastic_feeding_and_recovery_benchmark(dps)
    # monitor("test") { run_elastic_feeding_and_recovery_benchmark(dps) }
  end

  def teardown
    super
  end
end
