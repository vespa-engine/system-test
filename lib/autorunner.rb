# Copyright Vespa.ai. All rights reserved.

require 'testcase'
require 'testclasses'
require 'optparse'
require 'socket'

class AutoRunner

  def initialize
    @command_line_output = true
    @cmd_args = {}
    @cmd_args[:hostlist] = []
    @cmd_args[:configserverhostlist] = []
    @cmd_args[:nopreclean] = true
    @arg_testmethods = []
    @list_testmethods = false
  end

  def parse_args(usage = false)
    opts = OptionParser.new
    opts.on("--norestart", "Do not start or stop Vespa.") do
      @cmd_args[:nostop] = true
      @cmd_args[:nostart] = true
    end
    opts.on("--nostop", "Do not stop Vespa.") do
      @cmd_args[:nostop] = true
    end
    opts.on("--nostart", "Do not start Vespa.") do
      @cmd_args[:nostart] = true
    end
    opts.on("--nostop-if-failure", "Do not stop Vespa if the test fails.") do
      @cmd_args[:nostop_if_failure] = true
    end
    opts.on("--outputdir DIRECTORY", "Output directory for logs and graphs.") do |val|
      @cmd_args[:outputdir] = val
    end
    opts.on("--host HOSTNAME", "Run testcase on HOSTNAME.") do |val|
      @cmd_args[:hostlist] << get_full_hostname(val)
    end
    opts.on("--configserverhost HOSTNAME", "Config server to use for deploying in test.") do |val|
      @cmd_args[:configserverhostlist] << get_full_hostname(val)
    end
    opts.on("--configserverhostfile HOSTFILE", "Config servers to use for deploying in test.") do |val|
      if File.exist?(val)
        IO.foreach(val) do |line|

          # find all lines that are not blank
          if line =~ /\S+/
            full_hostname = get_full_hostname(line.chomp)
            if not @cmd_args[:configserverhostlist].include?(full_hostname)
              @cmd_args[:configserverhostlist] << full_hostname
            end
          end
        end
      else
        raise "File #{val} does not exist."
      end
    end
    opts.on("--hostfile HOSTFILE", "Run testcase on hosts in HOSTFILE.") do |val|
      if File.exist?(val)
        IO.foreach(val) do |line|

          # find all lines that are not blank
          if line =~ /\S+/
            full_hostname = get_full_hostname(line.chomp)
            if not @cmd_args[:hostlist].include?(full_hostname)
              @cmd_args[:hostlist] << full_hostname
            end
          end
        end
      else
        raise "File #{val} does not exist."
      end
    end
    opts.on("--valgrind COMPONENTS", "Space-separated list of components to run in valgrind.") do |val|
      @cmd_args[:valgrind] = val
    end
    opts.on("--valgrind_opt OPTIONS", "Options passed to valgrind.") do |val|
      @cmd_args[:valgrind_opt] = val
    end
    opts.on("--list", "Display all available testmethods in the testcase.") do
      @list_testmethods = true
    end
    opts.on("--run METHOD1,METHOD2", Array, "List of test methods to run, separated by comma.") do |val|
      @arg_testmethods = val
    end
    opts.on("--keep-tmpdir", "Do not remove the temporary testdir during test stop.") do
      @cmd_args[:keep_tmpdir] = true
    end
    opts.on("--leave-loglevels", "Do not alter log levels or remove logctl files.") do
      @cmd_args[:leave_loglevels] = true
    end
    opts.on("--perf-recording type", "perf recoding type {off, all}.") do | type |
      @cmd_args[:perf_recording] = type
    end
    opts.on("--vespa-version VERSION", String, "Specify vespa version being used, 5.1.3, 5.1.3.0.20120120.121212, etc") do |val|
      @cmd_args[:vespa_version] = val
    end
    opts.on("--prev-run PATH", String, "Specify the output path for previous test of this test") { |path|
      @cmd_args[:prev_path] = path
    }
    opts.on("--clean", "Clean up any leftover state or processes from previous runs before starting") {
      @cmd_args[:nopreclean] = false
    }
    opts.on("--forked URI", "DRb URI to systemtest controller responsible for this process") { |uri|
      @command_line_output = false
      @cmd_args.delete(:nopreclean) 
      @cmd_args[:forked] = uri
    }
    opts.on("--platform-label LABEL", String, "Platform label, example: RHEL7-64") { |v| @cmd_args[:platform_label] = v }
    opts.on("--build-version VERSION", String, "Build version, example: HEAD") { |v| @cmd_args[:buildversion] = v }
    opts.on("--build-name LABEL", String, "Build name, example: 6.10.51") { |v| @cmd_args[:buildname] = v }
    opts.on("--base-dir DIR", String, "Base directory") { |v| @cmd_args[:basedir] = v }
    opts.on("-?", "--help", "Display this help text.") {usage = true}

    begin
      opts.parse(ARGV)
    rescue StandardError => e
      puts "Error while parsing command line options:\n" + e.message + "\n\n"
      puts opts.to_s
      exit 1
    end
    if usage
      puts opts.to_s
      exit 0
    end

    if @cmd_args[:hostlist].empty?
      @cmd_args[:hostlist] << get_full_hostname("localhost")
    end
  end

  def get_full_hostname(hostport)
    hostname, port = hostport.split(":")

    if hostname == "localhost"
      full_hostname = Environment.instance.vespa_hostname
    elsif /vmnet\.yahoo\.com$/ =~ hostname
      full_hostname = hostname
    else
      hostname = Socket.gethostbyname(hostname)
      raise "Unable to lookup host #{hostname}." unless hostname
      full_hostname = hostname.first
    end

    port ? "#{full_hostname}:#{port}" : full_hostname
  end

  def instantiate_testcases
    testcases = {}
    TestClasses.each_class do |klass|
      test_methods = TestClasses.test_methods(klass)

      if test_methods.any?
        some_method = klass.original_public_instance_methods(false).first
        testcase_file = klass.instance_method(some_method).source_location.first
        testcase = klass.new(@command_line_output, testcase_file, @cmd_args)
        testcases[testcase] = test_methods
      end
    end

    testcases
  end

  def run
    arres = []
    parse_args

    unless @cmd_args[:vespa_version]
      @cmd_args[:vespa_version] = find_vespa_version()
    end

    instantiate_testcases.each do |testcase, test_methods|
      # if testmethods are specified on the cmdline, remove all other testmethods
      if not @arg_testmethods.empty?
        test_methods.delete_if { |method_name| not @arg_testmethods.include?(method_name.to_s) }
      end

      if not test_methods.empty?
        if @list_testmethods
          puts "Testmethods found in #{testcase.class.name}:"
          puts test_methods.sort.join("\n")
        else
          arres += testcase.run(test_methods)
        end
      end
    end
    arres
  end

  def find_vespa_version()
    output = `vespa-print-default version 2>&1`
    if $?.exitstatus != 0
      $stderr.puts "Unable to find vespa version using vespa-print-default: #{output}"
    elsif output.strip! =~ /^\d+\.\d+\.\d+$/
      vespa_version = output
      if vespa_version =~ /^(\d+)\.\d+\.0$/
        vespa_version = "#{$1}-SNAPSHOT"
      end
    else
      vespa_version = nil
    end
    return vespa_version
  end

end


if $0 == __FILE__
  runner = AutoRunner.new
  runner.run
end

