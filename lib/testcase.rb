# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# -*- coding: utf-8 -*-
require 'assertions'
require 'assertionfailederror'
require 'error'
require 'failure'
require 'test_base'
require 'testdirs'
require 'unit'
require 'json'
require 'drb'
require 'set'
require 'timeout'
require 'net/http'
require 'fileutils'
require 'vespa_cleanup'

class SystemTestTimeout < Interrupt
  def message
    "Testcase timed out."
  end
end

# This class is a superclass for each individual testcase. It utilizes introspection to run
# all methods starting with "test_". The testcase's setup method is run before each test method,
# and the teardown method is run after each test method.
# In addition, subclasses must implement the zero-argument "modulename" method to return a category name for the test case.
class TestCase
  include DRb::DRbUndumped
  include Assertions
  include TestBase

  attr_reader :selfdir, :dirs, :testcase_file, :cmd_args, :timeout, :max_memory, :keep_tmpdir, :leave_loglevels, :tls_env, :https_client, :perf_recording
  attr_accessor :hostlist, :num_hosts, :valgrind, :valgrind_opt, :failure_recorded, :testcategoryrun_id, :module_name, :required_hostnames, :expected_logged, :method_name
  attr_accessor :dirty_nodeproxies, :dirty_environment_settings
  attr_accessor :sanitizers

  # Creates and returns a new TestCase object.
  #
  # If _cmdline_ is true, output is printed on STDOUT, otherwise it is not.
  # _tc_file_ is the sourcefile of the testcase, used when tests are run on factory.
  #
  # Optional args:
  # * :hostlist - array of hostnames this testcase is running on
  # * :outputdir - directory to store output files, used when running datacenter tests
  # * :keep_tmpdir - Does not remove the tmpdir when testrun is done
  def initialize(cmdline, tc_file, args={})
    @dirs = TestDirs.new(self, 'unknown', 'unknown')
    @command_line_output = cmdline
    @testcase_file = tc_file
    @cmd_args = args
    @hostlist = args[:hostlist]
    @outputdir = args[:outputdir]
    @sanitizers = nil
    @perf_recording = args[:perf_recording]
    @valgrind = args[:valgrind]
    @valgrind_opt = args[:valgrind_opt]
    @keep_tmpdir = args[:keep_tmpdir]
    @leave_loglevels = args[:leave_loglevels]
    @filereaders = []
    @num_hosts = 1
    @dirty_nodeproxies = {}
    @dirty_environment_settings = false
    @disable_log_query_and_result = nil
    @connection_error = false
    @current_assert_file = nil
    @required_hostnames = nil
    @stop_timestamp = nil
    @vespa_version = args[:vespa_version]
    @vespa_cleanup = VespaCleanup.new(self, @cmd_args)
    @expected_logged = nil
    @use_shared_configservers = false
    @configserverhostlist = []
    @tenant_name = sanitize_name(self.class.name)
    @application_name = nil
    @tls_env = TlsEnv.new()
    @https_client = HttpsClient.new(@tls_env)
    # To avoid mass test breakage in case of known warnings, maintain a workaround
    # set of log messages to ignore.
    # ... don't keep them around for long, though!
    @ignorable_messages = [
      @@log_messages[:async_slow_resolve],
      @@log_messages[:slow_query],
      @@log_messages[:no_slobrok_brokers],
      @@log_messages[:uncommon_get],
      @@log_messages[:zkmetric_updater_monitor_failure],
      @@log_messages[:zookeeper_reconfig],
      @@log_messages[:zookeeper_shutdown],
      @@log_messages[:slow_processing],
      @@log_messages[:time_move_backwards],
      @@log_messages[:remove_dangling_file],
      @@log_messages[:canonical_hostname_warning],
      @@log_messages[:metrics_proxy_connection_refused],
      @@log_messages[:empty_idx_file],
      @@log_messages[:taking_search_node_oos],
      @@log_messages[:no_snapshot_from_instance]
    ]
    @valgrind_ignorable_messages = [
      @@log_messages[:valgrindrc_not_read],
      @@log_messages[:shutdownguard_forcing_exit],
      @@log_messages[:max_query_timeout],
      @@log_messages[:failed_find_2_consecutive],
      @@log_messages[:no_tick_registered],
      @@log_messages[:slobrok_failed_listnames_check]
    ]
    @https_downgrade_warnings = Set.new

    if args[:configserverhostlist] && !args[:configserverhostlist].empty?
      @configserverhostlist = args[:configserverhostlist]
      @use_shared_configservers = true
    end

    # set max memory limit, fail test when exceeding this
    # measured in gigabytes, can be overriden by the tests
    if cmdline
      @max_memory = 1000
    else
      @max_memory = 8
    end

    @selfdir = File.expand_path(File.dirname(@testcase_file))+'/'
    if @outputdir
      FileUtils.mkdir_p(@outputdir)
      raise 'Unable to create #{@outputdir}, make sure you have permission' unless File.directory?(@outputdir)
    end
  end

  def self.inherited(subclass)
    @decendants ||= []
    @decendants << subclass
  end

  def self.decendants
    @decendants
  end

  def find_recognized_method_name(method)
    method.gsub(/^test_/, '')
  end

  # Prepare any test case specific variables before setup is called
  def prepare
  end

  # Returns the name of the feeder binary to be used.
  def feeder_binary
    "vespa-feed-client"
  end

  def can_share_configservers?(method_name=nil)
    return false
  end

  def add_ignorable_messages(msgs)
    @ignorable_messages += msgs
  end

  def set_port_configserver_rpc(node, port=nil)
    node.set_port_configserver_rpc(port)
    if (port == nil)
      @dirty_environment_settings = true
    end
  end

  class << self
    alias original_public_instance_methods public_instance_methods

    def testparameters
      return nil
    end

    # test methods that should be unaltered
    def final_test_methods
      return []
    end

    def modified_test_methods
      return @modified_test_methods
    end

    def public_instance_methods(include_super)
      @modified_test_methods = {}
      method_names = original_public_instance_methods(include_super)

      augmented_methods = []
      params = testparameters
      final_methods = final_test_methods
      method_names.each do |method_name|
        method_name = method_name.to_s
        if method_name =~ /^test_/ && params && !final_methods.include?(method_name)
          params.each do |param_key, param_value|
            augmented_name = "#{method_name}__#{param_key}"
            @modified_test_methods[augmented_name] = [method_name, param_key]
            augmented_methods << augmented_name
          end
        else
          augmented_methods << method_name
        end
      end
      if RUBY_VERSION == "1.8.7"
        augmented_methods
      else
        augmented_methods.collect { |m| m.to_sym }
      end
    end
  end

  # return the timeout (in seconds) for each phase of this test
  # override in specific tests to provide longer timeout if needed
  def timeout_seconds
    return 1200
  end

  # method wrapping timeout_seconds, to multiply timeout by 5 if
  # test is run through valgrind
  def get_timeout
    if @valgrind
      return timeout_seconds * TestBase::VALGRIND_TIMEOUT_MULTIPLIER
    elsif has_active_sanitizers
      return timeout_seconds * TestBase::SANITIZERS_TIMEOUT_MULTIPLIER
    else
      return timeout_seconds
    end
  end

  def sanitize_name(appname)
    appname.gsub(":", "_").gsub("(", "").gsub(")", "").downcase
  end

  def setup_directories(test_method, starttime)
    @dirs = TestDirs.new(self.class, test_method, modulename,
                         @cmd_args.merge({:start_timestamp => starttime}))
  end

  def runmethod(test_method, real_test_method, test_results)
    begin
      @starttime = Time.now
      @method_name = test_method
      @result = TestResult.new(test_method)
      @result.starttime = @starttime
      @failure_recorded = false
      @stopped = nil
      @application_name = sanitize_name(@method_name)

      init_vespa_model(self, @vespa_version)

      @vespa_cleanup.clean(@vespa.nodeproxies)
      setup_directories(test_method, @starttime)
      @dirs.create_directories
      prepare

      output(" \n" +
             ">>>>> Running testcase '#{name}'\n" +
             ">>>>> from file '#{testcase_file}'.\n" +
             " \n")
      if has_active_sanitizers
        output("Active sanitizers are: #{@sanitizers}")
      else
        output("No active sanitizers")
      end
      output("My coredump dir is: #{@dirs.coredir}")
      output("My current work directory is: #{`/bin/pwd`}")
      Timeout::timeout(get_timeout, SystemTestTimeout) do |timeout_length|
        output("Timeout length (setup): " + timeout_length.to_s)
        if test_method !~ /(.*)__([A-Z_]+)$/
          setup
        end
        output("Timeout length (test_method: " + test_method.to_s + "): " +
               timeout_length.to_s)
        __send__(real_test_method)
      end
      check_performance(test_method) if performance?
    rescue DRb::DRbConnError => e
      if e.message =~ /Connection refused/
        output("CONNECTION ERROR: #{e.message}\nPlease make sure you have a node server running on all vespa nodes used in this test.")
        @connection_error = true
      end
      add_error(e)
    rescue RuntimeError, ExecuteError => e
      add_error(e)
    rescue AssertionFailedError => e
      add_failure(e.message, e.backtrace)
    rescue StandardError, ScriptError, SignalException => e
      add_error(e)
    rescue => e
      add_error(e)
    ensure
      savev = @vespa
      begin
        Timeout::timeout(get_timeout, SystemTestTimeout) do |timeout|
          teardown
        end
      rescue StandardError, ScriptError, SignalException => e
        add_error(e)
      ensure
        if cmd_args[:nostop]
          puts "Skipping delete application due to nostop"
        else
          delete_application
        end
      end
      begin
        @vespa_cleanup.kill_stale_processes(@vespa.nodeproxies)
        # @vespa_cleanup.remove_model_plugins(@vespa.nodeproxies)
      rescue Exception => ex
        puts "Failure during process cleanup: #{ex.message}, ignoring."
      end

      begin
        @vespa = nil
        @endtime = Time.now
        @result.endtime = @endtime
        @result.add_logfile('testoutput', @dirs.testoutput)

        # Copy remote log files to @dirs.vespalogdir
        copy_remote_vespa_logfiles(savev)

        add_vespa_logfiles
        add_logfiles(@dirs.valgrindlogdir)
        add_logfiles(@dirs.jdisccorelogdir)
        add_logfiles(@dirs.sanitizerlogdir)

        begin
          assert_no_valgrind_errors
        rescue AssertionFailedError => e
          add_valgrind_failure(e.message, e.backtrace)
        end
        begin
          assert_no_sanitizer_warnings
        rescue AssertionFailedError => e
          add_sanitizer_failure(e.message, e.backtrace)
        end
        if (not @stopped and not @command_line_output)
          add_failure("ERROR: Method 'stop' was not called at " +
                      "the end of the testcase.")
        end
        if not @connection_error
          output("\nTime  : #{@starttime} - #{@endtime}, ran for " +
                 "#{@endtime.to_i-@starttime.to_i} seconds." +
                 "\nResult: #{@result.assertion_count} Assertions, " +
                 "#{@result.failures.size} " +
                 "Failures, #{@result.errors.size} Errors.\n")
          check_coredumps(savev, @starttime, @endtime)
          log_result_faults
        end
      rescue Exception => e
        add_error(e)
      ensure
        test_results << @result
      end
    end
  end

  def copy_remote_vespa_logfiles(vespa_model)
    vespa_model.nodeproxies.values.each do |proxy|
      remote_dir = proxy.remote_eval('@testcase.dirs.vespalogdir')
      proxy.copy_remote_directory_to_local_directory(remote_dir, @dirs.vespalogdir)
    end
  rescue Exception => ex
    puts "Failure copying log files from remote nodes: #{ex.message}, ignoring."
  end

  def add_vespa_logfiles
    Dir.foreach(@dirs.vespalogdir) do |logname|
      next if logname == '.' || logname == '..'
      logpath = "#{@dirs.vespalogdir}/#{logname}"
      # For backwards compatibility
      if logname == 'vespa.log'
        logname = 'vespalog'
      end
      @result.add_logfile(logname, logpath)
    end
  end

  def add_logfiles(dir)
    Dir.foreach(dir) do |logname|
      next if logname == '.' || logname == '..'
      # Don't copy core files
      next if logname =~ /\.core\./
      logpath = "#{dir}/#{logname}"
      @result.add_logfile(logname, logpath)
    end
  end

  def accepted_providers
    nil
  end

  # Runs all methods in array _test_methods_.
  # Returns an array of TestResult objects.
  #
  # :call-seq:
  #   tc.run(test_methods) -> array of TestResult
  def run(test_methods)
    test_results = []

    test_methods.each do |test_method|
      runmethod(test_method.to_s, test_method, test_results)
    end

    dump_results(test_results) if @outputdir
    if (@command_line_output and not @connection_error)
      output_results(test_results)
    end
    test_results
  end

  def running_in_factory?
    ENV['VESPA_FACTORY_SYSTEMTESTS_DISABLE_AUTORUN'] == "1" ? true : false
  end

  def add_assertion
    @result.add_assertion
  end

  def add_failure(message, all_locations=caller())
    $stdout.puts "Add failure: "
    $stdout.puts message
    $stdout.puts all_locations.join("\n")
    failure = Failure.new(name, all_locations, message)
    @result.add_failure(failure)
    @failure_recorded = true
    output(failure.short_desc)
  end

  def add_valgrind_failure(message, all_locations=caller())
    $stdout.puts "Add valgrind failure: "
    $stdout.puts message
    $stdout.puts all_locations.join("\n")
    failure = Failure.new(name, all_locations, message)
    @result.add_valgrind_failure(failure)
    @failure_recorded = true
    output(failure.short_desc)
  end

  def add_sanitizer_failure(message, all_locations=caller())
    $stdout.puts "Add sanitizer failure: "
    $stdout.puts message
    $stdout.puts all_locations.join("\n")
    failure = Failure.new(name, all_locations, message)
    @result.add_sanitizer_failure(failure)
    @failure_recorded = true
    output(failure.short_desc)
  end

  def add_error(exception)
    $stdout.puts "Add error: "
    $stdout.puts exception.message
    $stdout.puts exception.backtrace.join("\n")
    error = Error.new(name, exception)
    @result.add_error(error)
    @failure_recorded = true
    output(error.short_desc)
  end

  def add_test_value(name, value, params={})
    @result.add_test_value(name, value, params)
  end

  # Sets the owner of the test (username).
  def set_owner(ownername)
    @result.owner = ownername
  end

  # Sets the description of the test.
  def set_description(desc)
    @result.description = desc
  end

  # Allows this test to fail if boolean_value is set to true.
  def allow_to_fail(ticket_number)
    if ticket_number
      @result.allow_ticket = ticket_number.to_s
    end
  end

  def check_coredumps(v, starttime, endtime)
    if v
      coredumps = v.check_coredumps(starttime, endtime)
      if not coredumps.empty?
        @result.add_coredumps(coredumps)
      end
    end
  end

  def create_filereader
    filereader = DocReader.new

    # keep local reference to filereader object, avoids premature GC
    @filereaders << filereader
    filereader
  end

  def add_dirty_nodeproxies(nodeproxies)
    @dirty_nodeproxies.merge!(nodeproxies)
  end

  def http_json(http_connection, path)
    v = nil
    output "not in cache, fetching #{path}"
    response = http_connection.get(path)
    if not response.code == "200"
      output "Could not get #{path} from #{http_connection.inspect}, error: #{response.code}"
    else
      v = JSON.parse response.body
    end
    v
  end

  # Appends failure, error and coredump information to the testlog in
  # the current TestResult object, unless the test passed successfully.
  def log_result_faults
    if not @result.passed?
      faults = @result.failures + @result.errors
      faults.each_with_index do |fault, index|
        output_log("\n%3d) %s\n" % [index + 1, fault.long_desc])
      end
      @result.coredumps.each do |hostname, corelist|
        output_log("Coredumps on host #{hostname}:\n")
        corelist.each {|core| output(core.corefilename)}
        output_log("Binaries and corefiles saved in #{hostname}:#{corelist.first.coredir}\n")
      end
    end
  end

  # Outputs a summary of all the tests to STDOUT.
  def output_results(test_results)
    total_tests = test_results.size
    total_assertions = 0
    total_failures = 0
    total_errors = 0

    test_results.each do |test_result|
      if test_result.status == "allow_failure"
        output_stdout("Test #{test_result.name} was allowed to fail, and failed\n")
      elsif test_result.status == "allow_success"
        output_stdout("Test #{test_result.name} was allowed to fail, but succeeded\n")
      end
      total_assertions += test_result.assertion_count
      if not test_result.passed?
        total_failures += test_result.failures.size
        total_errors += test_result.errors.size
        faults = test_result.failures + test_result.errors
        faults.each_with_index do |fault, index|
          output_stdout("\n%3d) %s\n" % [index + 1, fault.long_desc])
        end
        test_result.coredumps.each do |hostname, corelist|
          output_stdout("Coredumps on host #{hostname}:\n")
          corelist.each {|core| output_stdout(core.corefilename)}
          output_stdout("Binaries and corefiles saved in #{hostname}:#{corelist.first.coredir}\n")
        end
      end
    end
    output_stdout("In all: #{total_tests} Tests, #{total_assertions} Assertions, #{total_failures} Failures, #{total_errors} Errors.\n")
  end

  # Serializes all the TestResult objects to disk.
  def dump_results(test_results)
    File.open("#{@outputdir}/testresults.serialized", "w+") do |file|
      Marshal.dump(test_results, file)
    end
  end

  # Override default puts method.
  def puts(str='')
    output(str)
  end

  # Appends _str_ to log and also prints it to STDOUT if the test is
  # started from the command-line. This method should be used by all
  # other classes that needs output to screen and/or logfile.
  def output(str, newline=true)
    str = str.to_s
    if newline
      str += "\n"
    end

    # add timestamp info only to lines containing newlines
    if str =~ /\n/
      str_with_timestamps = ""
      str.split("\n").each do |line|
        timeformat = "%H:%M:%S"
        now = Time.now
        timestring = now.strftime(timeformat) + "." + ("%06d" % now.usec)[0..2]
        str_with_timestamps += "[#{timestring}] " + line + "\n"
      end
      str = str_with_timestamps
    end
    output_log(str)
    if @command_line_output
      output_stdout(str)
    end
  end

  # Returns a human-readable name for the specific test that
  # this instance of TestCase represents.
  def name
    "#{self.class.name}::#{@method_name}()"
  end

  def to_s
    name
  end

  # Checks
  # Override method missing method to allow for check(_.*) methods to
  # be assertions without the stop testrun side effect.
  def method_missing(sym, *args, &block)
    m = sym.to_s
    if m =~ /^check$/ or m =~ /^check_.+$/
      new_method = m.gsub(/^check/, 'assert')
      begin
        self.send(new_method.to_sym, *args, &block)
      rescue AssertionFailedError => e
        add_failure(e.message, e.backtrace)
        false
      end
    else
      if sym == :setup
        return
      end
      if m !~ /(.*)__([A-Z_]+)$/
        super(sym, *args, &block)
      end
      test_name = self.class.modified_test_methods[m][0]
      param_key = self.class.modified_test_methods[m][1]
      test_params = self.class.testparameters[param_key]
      if test_params.nil?
        raise "Could not find parameters for test '#{test_name}'"
      end

      param_setup test_params
      send test_name
    end
  end

  def performance?
    false
  end

  def log_query_and_result(query, result)
    return if @disable_log_query_and_result
    path = File.join(@dirs.tmpdir, 'query_result.log')
    File.open(path, 'a+') do |f|
      f.write("Query: #{query}\n")
      f.write("Result:\n#{result}")
    end
  end

  def install_maven_parent_pom(node)
    Maven.install_maven_parent_pom(node)
  end

  def maven_command
    "mvn #{if Environment.instance.maven_snapshot_url == nil then "-nsu" else "" end} --batch-mode -C -Daether.checksums.algorithms=SHA-1,SHA-256,MD5 -Dvespa.version=#{Maven.to_pom_version(@vespa_version)}"
  end

  def get_timestamp(deploy_output)
    deploy_output =~ /Timestamp:\s*\((\d+)\)/i
    return $1;
  end

  def get_checksum(deploy_output)
    deploy_output =~ /Checksum:\s*([0-9a-f]+)/i
    return $1;
  end

  def get_generation(deploy_output)
    deploy_output =~ /Generation:\s*(\d+)/i
    return $1;
  end

  def detected_sanitizers(sanitizers)
    @sanitizers = sanitizers if @sanitizers.nil?
  end

  #
  # Private methods follow.
  #

  private

  # Outputs _str_ to the testlog file on disk and to the TestResult's testlog.
  def output_log(str)
    if @outputdir
      outputfilename = @outputdir+"/testoutput.log"
      FileUtils.mkdir_p(@outputdir)
    else
      outputfilename = @dirs ? @dirs.testoutput : '/dev/null'
    end
    begin
      File.open(outputfilename, "a") do |file|
        file.print(str)
      end
    rescue Errno::ENOENT
    end
    @result.append_log(str) if @result
  end

  # Output _str_ on STDOUT.
  def output_stdout(str)
    STDOUT.print str
    STDOUT.flush
  end

  # Get an array of log services (i.e. ['qrserver\\d+']) that should be
  # checked, specified using regular expressions.
  # Override this in service-specific test base classes
  def get_default_log_check_services
    return ['[\\w-]+'] # All services
  end

  # Override this in component-specific test base classes (if needed)
  def get_default_log_check_levels
    return [:error, :fatal]
  end

  @@log_messages = {
    :async_slow_resolve => /slow resolve time:/,
    :slow_query => /Slow execution. query/,
    :slow_processing =>  /Slow processing of message/,
    :no_slobrok_brokers => /no location brokers available, retrying:/,
    :max_query_timeout => /Query timeout \(\d+ ms\) > max query /,
    :uncommon_get => /a little uncommon that GET method returns always/,
    :could_not_get_config => /Could not get config, please check your setup/,
    :no_tick_registered =>  /Thread .+ has gone \d+ milliseconds without registering a tick/,
    :zkmetric_updater_monitor_failure => /Failure in retrieving monitoring data:/,
    :valgrindrc_not_read => /\/home\/builder\/\.valgrindrc was not read/,
    :shutdownguard_forcing_exit => /ShutdownGuard is now forcing an exit of the process/,
    :failed_find_2_consecutive => /We failed to find 2 consecutive samples that where similar with epsilon of 1048576/,
    :zookeeper_reconfig => /Reconfiguration attempt \d+ failed. Retrying in .+ KeeperErrorCode = ConnectionLoss/,
    :zookeeper_shutdown => /Starting non-reconfigurable ZooKeeper server failed on attempt/,
    :time_move_backwards => /Time has moved backwards/,
    :metrics_proxy_connection_refused => /Failed retrieving metrics for '.+' : Connect to .+ failed: Connection refused/,
    :empty_idx_file => /We detected an empty idx file for part/,
    :remove_dangling_file => /Removing dangling file/,
    :canonical_hostname_warning => /Host named '.+' may not receive any config since it differs from its canonical hostname/,
    :no_snapshot_from_instance => /no snapshot from instance of /,
    :taking_search_node_oos => /Taking search node in cluster = .+ in group .+ out of service/,
    :slobrok_failed_listnames_check => /failed check using listNames callback/
  }

  # Allow that certain log messages may be ignored without the individual
  # test cases specifying them in their blocks. Meant for known cases
  # that would cause a lot of tests to fail needlessly.
  # Override this in component-specific test base classes
  def should_ignore_log_message(line)
    if not @ignorable_messages.select { |regex| regex.match(line) }.empty?
      return true
    end

    if @valgrind
      if not @valgrind_ignorable_messages.select { |regex| regex.match(line) }.empty?
        return true
      end
    end
    return matches_expected_logged?(line)
  end

  def matches_expected_logged?(line)
    return false if @expected_logged.nil?
    @expected_logged.match(line)
  end

  def get_expected_logged_presets(presets={})
    r = //
    presets.each_key do |key|
      log_message = @@log_messages[key]
      value = (log_message ? log_message : key)
      r = Regexp.union(r, value)
    end
    if r == //
      nil
    else
      r
    end
  end

  def add_expected_logged(expected)
    if @expected_logged
      @expected_logged = Regexp.union(expected, @expected_logged)
    else
      @expected_logged = expected
    end
  end

  def set_expected_logged(expect, presets={})
    if expect == //
      expect = nil
    end
    presets_regex = get_expected_logged_presets(presets)
    if expect and presets_regex
      @expected_logged = Regexp.union(expect, presets_regex)
    elsif expect
      @expected_logged = expect
    elsif presets_regex
      @expected_logged = presets_regex
    end
    if !@expected_logged.nil?
      output "Using log match regexp #{@expected_logged}"
    end
  end


  def timestamp_within_test_range(timestamp)
    return (@stop_timestamp.nil? or \
            timestamp < @stop_timestamp)
  end

  def read_log_from_logserver
    log = ''
    vespa.logserver.get_vespalog { |data|
      log << data
      nil
    }
    log
  end

  def scan_log_for_unexpected_entries(log, components, levels)
    output "Scanning for unexpected log entries, ignoring these messages: #{@ignorable_messages}"
    if @valgrind
        output "Scanning for unexpected log entries, ignoring these messages as we are running under valgrind: #{@valgrind_ignorable_messages}"
    end
    # timestamp host pid/threadid component logger level msg
    regex_str = "^([\\d\\.]+)\\s+(?:[^\\s]+\\s+){2}(?:#{components.join('|')})\\s+[^\\s]+\\s+(?:#{levels.join('|')})(.*)"
    regex = Regexp.new(regex_str)
    log_errors = []

    log.each_line do |line|
      if regex.match(line)
        timestamp = $~[1].to_f
        msg = $~[2].strip
        next if !timestamp_within_test_range(timestamp)
        if not (should_ignore_log_message(line) or (block_given? and yield line))
          # Add both full, raw line and the message itself
          log_errors << [line, msg]
        end
      end
    end
    log_errors
  end

  def eliminate_log_duplicates_and_return_n_first(log_errors, max_errors_reported)
    seen = Set.new
    dupes_eliminated = 0

    # Keep as own array to maintain original ordering
    report = []
    # Don't report exact duplicates
    log_errors.each do |entry|
      if seen.include? entry[1]
        dupes_eliminated += 1
        next
      end
      break if report.size == max_errors_reported
      report << entry[0]
      seen.add entry[1]
    end
    [report, dupes_eliminated]
  end

  # Filter log, applying block to each log entry matching both the service(s) and
  # the log level(s) to be checked. If the block returns false, the function triggers
  # an assertion.
  # Common usage:
  #   assert_only_expected_logged { |line| line =~ /expected messages/ }
  # or simply (to use defaults):
  #   assert_only_expected_logged
  #
  # Check can be limited to specific services (regex) and levels:
  #   assert_only_expected_logged(['qrserver\\d*'], :error) { |line| line =~ /foo/ }
  #
  def assert_only_expected_logged(services=[], *levels)
    return unless (vespa && vespa.logserver)
    services = get_default_log_check_services if services.empty?
    levels = get_default_log_check_levels if levels.empty?

    log = read_log_from_logserver()
    log_errors = scan_log_for_unexpected_entries(log, services, levels)

    max_errors_reported = 10
    report, dupes_eliminated = eliminate_log_duplicates_and_return_n_first(log_errors, max_errors_reported)

    if not log_errors.empty?
      flunk("Log contained #{log_errors.size} unexpected entries (showing " +
            "max #{max_errors_reported} here. #{dupes_eliminated} " +
            "duplicates eliminated):\n#{report.join}")
    end
  end

  def wait_for_application(qrserver, deploy_output)
    checksum = get_checksum(deploy_output)
    if checksum == nil
      flunk "Could not extract checksum from deploy output.\n" +
        "(Maybe the output from deploy has been changed without updating the test framework.)"
    end

    limit = 180
    start = Time.now.to_i
    puts "start=#{start}"
    while Time.now.to_i - start < limit
      begin
        sleep 1
        res = qrserver.search("/ApplicationStatus")
        root = JSON.parse(res.xmldata)

        if ! root.has_key? 'application'
          flunk "No 'application' key in json output: #{res}"
        end
        qrs_checksum = root['application']['meta']['checksum']

        if qrs_checksum != checksum
          puts "Waiting for application checksum #{checksum}, got #{qrs_checksum}"
        else
          puts "Got application checksum #{checksum}"
          break
        end
      rescue StandardError => e
        puts "Failed getting application status: #{e}"
      end
    end
    if qrs_checksum != checksum
      flunk "Did not get application checksum #{checksum} in #{Time.now.to_i - start} seconds"
    end
  end

  def pre_stop
    if not failure_recorded
      if @expected_logged.nil?
        assert_only_expected_logged
      else
        assert_only_expected_logged {
          |line| line =~ @expected_logged
        }
      end
      output "Log check OK"
    else
      output "Testcase failed, skipping log checks"
    end
  end

  def post_stop
  end

  def compare_to_previous_dir(method, prevpath)
    # Currently empty
  end

  # Attach a file or a directory
  # It will be linked to on the testrun page
  def attach_to_factory_report(source, content=nil)
    if content
      path = File.join(dirs.filesdir, source)
      File.open(path, 'w') { |file|
        file.write(content)
      }
    else
      FileUtils.cp_r(source, dirs.filesdir)
    end
  end

  # Attach a file or a directory from a remote node
  # It will be linked to on the testrun page
  def attach_to_factory_report_from_remote(node_proxy, path)
    if node_proxy.file?(path)
      node_proxy.copy_remote_file_into_local_directory(path, dirs.filesdir)
    elsif node_proxy.directory?(path)
      node_proxy.copy_remote_directory_into_local_directory(path, dirs.filesdir)
    else
      raise path + " is neither a file nor a directory on " + node_proxy.name
    end
  end

  def rename_and_use_sd_file(sdfile, new_name)
    destination_file = "#{dirs.tmpdir}/#{new_name}"
    system("cp #{sdfile} #{destination_file}")
    destination_file
  end

  def restart_proton(doc_type, exp_hits, cluster = "search", skip_trigger_flush: false)
    node = vespa.search[cluster].first
    unless skip_trigger_flush
      node.trigger_flush
    end
    node.stop
    node.start
    wait_for_hitcount("sddocname:#{doc_type}&nocache&streaming.selection=true", exp_hits, 180)
  end

end
