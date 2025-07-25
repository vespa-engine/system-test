# Copyright Vespa.ai. All rights reserved.

require 'performance/configloadtester'
require 'performance/fbench'
require 'performance/resultmodel'
require 'environment'
require 'json'

require 'testcase'

class PerformanceTest < TestCase
  attr_reader :result
  attr_accessor :resultoutputdir
  attr_accessor :perfdir
  attr_accessor :profilersnapshotdir

  def initialize(*args)
    # 'stress_test' definition:
    #
    # automatic test that have more than 1000 documents and wants to
    # figure out whether the distributor is in sync or not by fetching
    # a HTML page describing the state of all buckets owned by that
    # distributor and grepping for bold tags to count buckets that are
    # out of sync. When cleverness meets RHEL6 we need more than 5
    # seconds worth of timeout.
    #
    cmdline, tc_file, arg_pack = args
    arg_pack[:stress_test] = true
    super(cmdline, tc_file, arg_pack)

    @queryfile = selfdir + 'queries.txt'
    @warmup = true
    @perf_processes = {}
    @perf_record_pids = {}
    @perf_data_dir = "#{Environment.instance.vespa_home}/tmp/perf/"
    @perf_data_file = File.join(@perf_data_dir,'record.data')
    @perf_stat_file = File.join(@perf_data_dir,'perf_stats')
    @vespa_user = Environment.instance.vespa_user
    @curr_user = `id -un`.chomp
    @script_user = get_script_user
    @sudo_to_v = ""
    @need_chown = false
    if @vespa_user != @script_user or @curr_user == "root"
      @sudo_to_v = "sudo -u #{@vespa_user}"
      @need_chown = true
    end
  end

  def timeout_seconds
    3600
  end

  def can_share_configservers?
    true
  end

  def get_script_user
    sudo_user = `echo ${SUDO_USER}`.chomp
    user = @curr_user
    if sudo_user != nil && sudo_user != ""
      user = sudo_user
    end
    user
  end

  def deploy_app(app, deploy_params = {})
    # Override distribution bits to avoid few buckets preventing write concurrency in the backend.
    # If there is someone who knows how to do this in a more 'app_generator' way, feel free.
    app.config(ConfigOverride.new('vespa.config.content.fleetcontroller').
        add('ideal_distribution_bits', distribution_bits))
    app.config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
        add('minsplitcount', distribution_bits))
    super(app, deploy_params)
  end

  def distribution_bits
    12
  end

  def modulename
    "performance"
  end

  def feeder_numthreads
      2
  end

  def default_feed_client
    :vespa_feed_perf
  end

  def prepare
    super
    @magic_number = 0
    @resultoutputdir = @dirs.resultoutput + 'performance/'
    `mkdir #{@resultoutputdir}`
    @perfdir = @dirs.resultoutput + 'perf/'
    `mkdir #{@perfdir}`
  end

  def run_simple(clients, ntimes)
    prepare
    qrserver = @vespa.qrserver.values.first
    warmup(qrserver) if @warmup
    clients.each do |num_clients|
      puts "Running with #{num_clients} clients, #{ntimes} iterations"
      run_fbench_ntimes(qrserver, num_clients, 300, ntimes)
    end
  end

  def run_fbench_ntimes(qrserver, clients, runtime, ntimes, custom_fillers=[], params={})
    ntimes.times do |run|
      puts "Running iteration #{run}"
      run_fbench(qrserver, clients, runtime, custom_fillers, params)
    end
  end

  def run_fbench(qrserver, clients, runtime, custom_fillers=[], params={})
    run_fbench2(qrserver, @queryfile, params.merge({:runtime => runtime, :clients => clients}), custom_fillers)
  end

  def run_fbench2(container, queryfile, params={}, custom_fillers=[])
    system_fbench = Perf::System.new(container)
    system_fbench.start
    container_port = if params[:port_override] then params[:port_override] else container.http_port end
    container_hostname = if params[:hostname_override] then params[:hostname_override] else container.name end
    fbench = Perf::Fbench.new(container, container_hostname, container_port)

    fbench.runtime = params[:runtime] if params[:runtime]
    fbench.clients = params[:clients] if params[:clients]
    fbench.max_line_size = params[:max_line_size] if params[:max_line_size]
    fbench.use_post = params[:use_post] if params[:use_post]
    fbench.append_str = params[:append_str] if params[:append_str]
    fbench.headers = params[:headers] if params[:headers]
    fbench.ignore_first = params[:ignore_first] if params[:ignore_first]
    fbench.request_per_ms = params[:requests_per_ms] if params[:requests_per_ms]
    fbench.times_reuse_query_files = params[:times_reuse_query_files] if params[:times_reuse_query_files]
    fbench.result_file = params[:result_file] if params[:result_file]
    fbench.disable_http_keep_alive = params[:disable_http_keep_alive] if params[:disable_http_keep_alive]
    fbench.disable_tls = params[:disable_tls] if params[:disable_tls]
    fbench.certificate_file = params[:certificate_file] if params[:certificate_file]
    fbench.private_key_file = params[:private_key_file] if params[:private_key_file]
    fbench.ca_certificate_file = params[:ca_certificate_file] if params[:ca_certificate_file]
    fbench.single_query_file = params[:single_query_file] if params[:single_query_file]

    fbench.query(queryfile)
    system_fbench.end
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end

  def fill_feeder(output)
    Proc.new do |result|
      result.add_metric('feeder.runtime', output[0])
      result.add_metric('feeder.okcount', output[1])
      result.add_metric('feeder.errorcount', output[2])
      result.add_metric('feeder.minlatency', output[3])
      result.add_metric('feeder.maxlatency', output[4])
      result.add_metric('feeder.avglatency', output[5]) if output[5]
      result.add_metric('feeder.throughput', (output[1].to_f / output[0].to_f * 1000).to_s)
      result.add_parameter('loadgiver', 'vespafeeder')
    end
  end

  def fill_feeder_json(json)
    Proc.new do |result|
      result.add_metric('feeder.runtime', json['feeder.seconds'].to_s)
      result.add_metric('feeder.okcount', json['feeder.ok.count'].to_s)
      result.add_metric('feeder.errorcount', json['feeder.error.count'].to_s)
      result.add_metric('feeder.throughput', json['feeder.ok.rate'].to_s)
      result.add_metric('feeder.minlatency', json['http.response.latency.millis.min'].to_s)
      result.add_metric('feeder.maxlatency', json['http.response.latency.millis.max'].to_s)
      result.add_metric('feeder.avglatency', json['http.response.latency.millis.avg'].to_s)
      operation_latency = json.dig("operation.latency", "avg")
      result.add_metric("feeder.operation.avg_latency", operation_latency.to_s) if operation_latency
      response_200_latency = json.dig("http.response", "200", "latency", "avg")
      result.add_metric('feeder.response.200.avg_latency', response_200_latency.to_s) if response_200_latency
      result.add_parameter('loadgiver', 'vespa-feed-client')
    end
  end

  def post_process_feed_output(output, client, custom_fillers, warmup=false)
    if warmup
      fillers = []
    else
      if client == :vespa_feed_client
        json = '[' + output.gsub('}{', '},{') + ']'
        feed_outputs = JSON.parse(json)
        last_feed_output = feed_outputs[-1]
        fillers = [fill_feeder_json(last_feed_output)]
      else
        lines = output.split("\n")[-1]
        res = lines.gsub(/\s+/, "").split(",")
        fillers = [fill_feeder(res)]
      end
    end
    write_report(fillers + custom_fillers)
  end

  def run_feeder(feedfile, custom_fillers=[], feederparams={})
    out = feed(feederparams.merge({:file => feedfile, :mode => "benchmark", :do_sync => true}))
    post_process_feed_output(out, feederparams[:client], custom_fillers, feederparams.dig(:warmup) || false)
  end

  def run_stream_feeder(streamer_command, custom_fillers=[], feederparams={})
    client = feederparams.key?(:client) ? feederparams[:client] : default_feed_client
    out = feed_stream(streamer_command,
                      feederparams.merge({:client => client, :mode => "benchmark"}))
    post_process_feed_output(out, client, custom_fillers, feederparams.dig(:warmup) || false)
  end

  def run_template_feeder(fillers: [], params: {}, template: params[:template], count: params[:count])
    raise "Template must be present" unless template
    out = feed(params.merge({:template => template, :count => count, :mode => "benchmark"}))
    post_process_feed_output(out, params[:client], fillers, params.dig(:warmup) || false)
  end

  def create_loadtester(node, configserver_hostname, port, num_requests, num_threads, defdir)
    loadtester = Perf::ConfigLoadTester.new(node, configserver_hostname, port, defdir)
    loadtester.numiter = num_requests
    loadtester.threads = num_threads
    loadtester
  end

  def run_config_loadtester(loadtester, file, custom_fillers=[], debug=false)
    loadtester.run(file, debug)
    fillers = [loadtester.fill]
    write_report(fillers + custom_fillers)
  end


  def perfmap_jvmarg
    "-XX:+UnlockDiagnosticVMOptions -XX:+DumpPerfMapAtExit"
  end

  # Create a key-value tag to attach to the metrics produced which can be used to filter and label graphed values
  def parameter_filler(name, value)
    Proc.new do |result|
      result.add_parameter(name, value)
    end
  end

  def metric_filler(name, value)
    Proc.new do |result|
      result.add_metric(name, value)
    end
  end

  def write_report(fillers)
    @rep_result = Perf::Result.new(@vespa_version)
    fillers.each do |filler|
      filler.call(@rep_result)
    end
    @rep_result.add_parameter('hosts', hostlist.join(","))

    out = @resultoutputdir + Time.now.strftime('%Y-%m-%d-%H-%M-%S') + '_' + @magic_number.to_s + '.xml'
    @magic_number = @magic_number + 1
    @rep_result.write(out)
    # puts "Wrote result to: #{out}"
    @rep_result
  end

  def warmup(qrserver, warmup_time=30)
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)

    puts "Warming up for #{warmup_time}s*2"
    fbench.clients = 32
    fbench.runtime = warmup_time

    fbench.query(@queryfile)
    fbench.query(@queryfile)
  end

  def teardown
    vespa_destination_stop
    profiler_stop
    profiler_report
    stop
  end

  def setup
    profiler_start
  end

  # Start profiler. Calling this will stop any profilers started earlier and reset recordings.
  def profiler_start
    start_perf_profiler
  end

  # Generate reports from profile recordings. This call stop the profilers if running to
  # get a correct data dump. Multiple calls with the same label will overwrite the previous reports.
  def profiler_report(label='', extra_pids={})
    report_perf_profiler(label, extra_pids)
  end

  # Stop the currently running profilers.
  def profiler_stop
    stop_perf_profiler
  end

  def start_perf_profiler
    if @perf_recording == "off"
      return
    end
    stop_perf_profiler
    Timeout::timeout(600) do |timeout_length|
      puts "Starting perf record on nodes."
      @perf_record_pids = {}
      vespa.nodeproxies.values.each do | node |
        begin
          node.execute("rm -rf #{@perf_data_dir} && mkdir -p #{@perf_data_dir}")

          @perf_record_pids[node] = {}
          @perf_record_pids[node]['proton-bin'] = node.get_pids('sbin/vespa-proton-bin')
          @perf_record_pids[node]['container'] = node.get_pids('"java.*-Dconfig.id=[^[:space:]]*/container[.][0-9]"')
          if @perf_recording == "all"
            @perf_record_pids[node]['storaged-bin'] = node.get_pids('sbin/vespa-storaged-bin')
            @perf_record_pids[node]['distributord-bin'] = node.get_pids('sbin/vespa-distributord-bin')
            @perf_record_pids[node]['configserver'] = node.get_pids('"java.*jdisc\/configserver"')
            @perf_record_pids[node]['vespa-config-loadtester'] = node.get_pids('vespa-config-loadtester')
            @perf_record_pids[node]['programmatic-feed-client'] = node.get_pids('javafeedclient')
          end

          @perf_processes[node] = []
          @perf_record_pids[node].each do | name, pids |
            pids.each do | pid |
              @perf_processes[node] << node.execute_bg("perf record -e cycles -F 999 -p #{pid} -o #{@perf_data_file}-#{pid}")
              @perf_processes[node] << node.execute_bg("perf stat -ddd -p #{pid} -o #{@perf_stat_file}-#{name}-#{pid}")
            end
          end
          if @perf_recording == "all"
            @perf_processes[node] << node.execute_bg("perf record -e cycles -F 999 -a -o #{@perf_data_file}-0")
          end
        rescue ExecuteError
          puts "Unable to start perf on node #{node.name}"
        end
      end
    end
  rescue Timeout::Error
    raise "Timeout waiting for perf to start"
  end

  def perf_dir_name(label, node)
    File.join(@perf_data_dir, label.empty? ? "#{node.name}" : "#{label}_#{node.name}")
  end

  def report_perf_profiler(label, extra_pids)
    stop_perf_profiler
    if @perf_recording == "off"
      puts "Perf profiling turned off."
      return
    elsif @perf_record_pids == nil || @perf_record_pids.empty?
      puts "No perf recording was done at all."
      return
    else
      puts ">>> Generating perf report."
    end

    reporter_pids = {}
    vespa.nodeproxies.values.each do | node |
      # do we really need this?
      node.execute("chown root:root /tmp/perf-*.map", {:exceptiononfailure => false}) if @need_chown

      dir_name = perf_dir_name(label, node)
      node.execute("mkdir -p #{dir_name}")

      name_to_pids = extra_pids.clone
      name_to_pids.merge!(@perf_record_pids[node])

      reporter_pids[node] = []
      name_to_pids.each do | name, pids |
        pids.each do | pid |

          if extra_pids.key?(name)
            # Extra program pids must be picked from a system wide perf record and will not have stat files
            data_file = "#{@perf_data_file}-0"
            stat_file = nil
          else
            data_file = "#{@perf_data_file}-#{pid}"
            stat_file = "#{@perf_stat_file}-#{name}-#{pid}"
          end
          file_name = File.join(dir_name, "perf_#{name}-#{pid}")

          begin
            # Only execute the perfmap dump for java containers
            if name =~ /container/
              node.execute("ps -p #{pid} | grep java && #{@sudo_to_v} jcmd #{pid} Compiler.perfmap", {:exceptiononfailure => false})
              node.execute("chown root:root /tmp/perf-*.map", {:exceptiononfailure => false}) if @need_chown
            end
            filter = '/^# event : name = cycles.*/d;/# event : name/s/id = { [^}]* }/id = { ... }/;s/[.]\{5,255\}/.../g'
            fixed_opts = '--stdio --header --show-nr-samples --percent-limit 0.01'
            node.execute("perf report #{fixed_opts} --pid #{pid} --input #{data_file} 2>/dev/null | sed '#{filter}' > #{file_name}")
            node.execute("cp -a #{stat_file} #{dir_name}") if stat_file
          rescue ExecuteError
            puts "Unable to generate report for #{name} on host #{node.name}"
          end
        end
      end
      # mark all as done:
      @perf_record_pids[node] = {}
    end

    vespa.nodeproxies.values.each do | node |
      reporter_pids[node].each do | pid |
        node.waitpid(pid)
      end
      dir_name = perf_dir_name(label, node)
      puts "Copy files from #{dir_name} on host #{node.name} --> #{@perfdir}"
      node.copy_remote_directory_into_local_directory(dir_name, @perfdir)
    end
  end

  def stop_perf_profiler
    unless @perf_processes.empty?
      puts "Stopping perf recording."
      @perf_processes.each do |node, pidlist|
        pidlist.each do |pid|
          begin
            if node.pid_running(pid)
              puts "Stopping perf pid #{pid} on #{node.name}"
              Timeout.timeout(20) do
                node.kill_pid(pid, 'INT')
              end
           else
              puts "Perf pid #{pid} on #{node.name} already stopped"
           end
          rescue Timeout::Error, ExecuteError
            puts "Failed to stop pid #{pid} on host #{node.name}, trying HUP."
            begin
              node.kill_pid(pid, 'HUP')
            rescue ExecuteError, SystemCallError
              puts "Failed to terminate pid #{pid} on host #{node.name}"
            end
          end
          if node.pid_running(pid)
            puts "Using KILL on pid #{pid} on host #{node.name}"
            node.kill_pid(pid, 'KILL')
         end
        end
      end
      @perf_processes.clear
    end
  end

  private :start_perf_profiler, :perf_dir_name, :report_perf_profiler, :stop_perf_profiler

  def get_performance_results(path=nil)
    if path
      perf_path = path
    else
      result = dirs.resultoutput
      perf_path = File.join(result, 'performance/')
    end
    return [] unless File.exist?(perf_path)

    results = []
    Dir.foreach(perf_path) do |file|
      next if file =~ /^\./
      results << Perf::Result.read(File.join(perf_path, file))
    end
    results
  end

  def check_performance(method)
    puts "#### Performance results ####"
    get_performance_results.each { |result| puts result.to_json }
    puts "\n"
  end

  def performance?
    true
  end

  def get_default_log_check_levels
    return [:nothing]
  end

  # Note: teardown will stop process by calling vespa_destination_stop
  def vespa_destination_start
    @vespa_destination_pid = vespa.adminserver.execute_bg("#{Environment.instance.vespa_home}/bin/vespa-destination --instant --silent 1000000000")
    puts "Started vespa-destination #{@vespa_destination_pid}"
  end

  def vespa_destination_stop
    puts "Stop vespa-destination #{@vespa_destination_pid}"
    vespa.adminserver.kill_pid(@vespa_destination_pid) if @vespa_destination_pid
  end

  # Downloads the given file from s3 to the given vespa node.
  # If the file already exists in the test directory, use that directly instead.
  def download_file_from_s3(file_name, vespa_node, dir = "")
    url = "https://data.vespa-cloud.com/tests/performance/#{dir}"
    if File.exist?(selfdir + file_name)
      # Place the file in the test directory to avoid downloading during manual testing.
      puts "Using local file #{file_name}"
      selfdir + file_name
    else
      node_file = dirs.tmpdir + file_name
      if execute(vespa_node, "test -f #{node_file}")[0] == 0
        puts "Using already downloaded file #{file_name}"
      else
        puts "Downloading file #{file_name} from #{url} ..."
        vespa_node.fetchfiles(:testdata_url => url,
                              :file => file_name,
                              :destination_file => node_file)
      end
      node_file
    end
  end

end
