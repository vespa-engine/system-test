# Copyright Vespa.ai. All rights reserved.
#
# This helper integrates async-profiler for CPU profiling and flamegraph generation
# of the Java container process during performance tests.
#
# Installation instructions:
# 1. Download the latest release from: https://github.com/async-profiler/async-profiler/releases
# 2. For ARM64 Linux: wget https://github.com/async-profiler/async-profiler/releases/download/v4.2/async-profiler-4.2-linux-arm64.tar.gz
# 3. Extract to /tmp: tar -xzf async-profiler-4.2-linux-arm64.tar.gz -C /tmp
# 4. Ensure the profiler binary is at: /tmp/async-profiler-4.2-linux-arm64/bin/asprof
#
# If the profiler is not installed, tests will still run successfully but will not generate flamegraphs.

module AsyncProfilerHelper

  def start_async_profiler(container, duration_sec)
    container_pid = nil
    begin
      netstat_result = container.execute("lsof -ti :8080 -s TCP:LISTEN 2>/dev/null || ss -tlnp | grep :8080 | grep -oP 'pid=\\K[0-9]+'").strip
      if !netstat_result.empty?
        container_pid = netstat_result.split("\n").first
        puts "\nFound container on port 8080 with PID: #{container_pid}"
      end
    rescue => e
      puts "\nCould not use lsof/ss to find container on port 8080: #{e.message}"
    end

    if container_pid.nil? || container_pid.empty?
      begin
        result = container.execute("pgrep -f 'service/container' | grep -v clustercontroller").strip
        if !result.empty?
          container_pid = result.split("\n").first
          puts "\nFound container service with PID: #{container_pid}"
        end
      rescue => e
        puts "\nCould not find container service: #{e.message}"
      end
    end

    if container_pid.nil? || container_pid.empty?
      puts "\n=== WARNING: Could not find search container process PID, skipping async-profiler ==="
      return nil
    end

    async_profiler_dir = "#{Environment.instance.vespa_home}/tmp/async_profiler"
    container.execute("mkdir -p #{async_profiler_dir}")

    puts "\n=== Starting async-profiler on container PID #{container_pid} for #{duration_sec}s ==="
    profiler_cmd = "/tmp/async-profiler-4.2-linux-arm64/bin/asprof -d #{duration_sec} -f #{async_profiler_dir}/flamegraph.html #{container_pid}"
    container.execute("nohup #{profiler_cmd} > #{async_profiler_dir}/async_profiler.log 2>&1 &")
    puts "Async-profiler started, will run for #{duration_sec} seconds"
    return container_pid
  end

  def collect_async_profiler_results(container, permanent_name = nil)
    sleep 2

    async_profiler_dir = "#{Environment.instance.vespa_home}/tmp/async_profiler"

    begin
      log = container.execute("cat #{async_profiler_dir}/async_profiler.log 2>&1")
      puts log

      local_dir = dirs.tmpdir + "flamegraph.html"
      container.copy("#{async_profiler_dir}/flamegraph.html", local_dir)

      local_files = Dir.glob("#{local_dir}/**/*.html")
      local_flamegraph = local_files.empty? ? "#{local_dir}/flamegraph.html" : local_files.first

      if permanent_name && File.exist?(local_flamegraph) && File.file?(local_flamegraph)
        require 'fileutils'
        permanent_dir = dirs.resultoutput + "async_profiler"
        FileUtils.mkdir_p(permanent_dir)
        permanent_path = "#{permanent_dir}/#{permanent_name}.html"
        FileUtils.cp(local_flamegraph, permanent_path)
        puts "Flamegraph saved: #{permanent_path} (#{File.size(permanent_path)} bytes)"
      end
    rescue => e
    end
  end

  def run_fbench2_with_async_profiler(container, queryfile, params, custom_fillers=[], profile_name)
    async_profiler_pid = start_async_profiler(container, params[:runtime])
    profiler_start
    run_fbench2(container, queryfile, params, custom_fillers)
    profiler_report(profile_name)
    collect_async_profiler_results(container, profile_name) if async_profiler_pid
  end

end
