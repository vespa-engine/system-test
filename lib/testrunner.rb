# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'cloudconfig_test'
require 'container_test'
require 'search_container_test'
require 'docproc_test'
require 'performance_test'
require 'search_test'
require 'vds_test'
require 'hosted_test'
require 'test_node_pool'
require 'backend_reporter'
require 'concurrent'

class TestRunner

  def initialize(logger, **options)
    @log = logger
    @testmodule_dir = "#{__dir__}/../tests"
    @node_pool = TestNodePool.new(logger)
    @relative_testfiles = options[:testfiles]
    @nodelimit = options[:nodelimit]
    @basedir = options[:basedir]
    @vespaversion = options[:vespaversion] ? options[:vespaversion] : "7-SNAPSHOT"
    @performance = options[:performance] ? true : false
    @keeprunning = options[:keeprunning] ? true : false
    @consoleoutput = options[:consoleoutput] ? true : false
    @backend = BackendReporter.new(@log)
  end

  def initialize_run_dependent_fields
    @tests = {}
    @test_objects = {}
    @testclasses_not_run = Set.new
    @nodes_required = 0
  end

  def run
    initialize_run_dependent_fields
    require_testcases
    instantiate_testcase_objects
    compute_nodes_required
    scan_for_test_methods

    wait_until = Time.now.to_i + 60
    while Time.now.to_i < wait_until && @node_pool.max_available < @nodes_required
      sleep 5
      @log.info "Waiting for at least #{@nodes_required} to become available. Currently #{@node_pool.max_available}."
    end

    if @node_pool.max_available >= @nodes_required
      @log.info "Running #{@test_objects.size} test cases."
      run_tests
    else
      @log.error "Tests require minimum #{@nodes_required}, but found only #{@node_pool.max_available}. Exiting."
      false
    end
  end

  private

  def require_testcases
    if not @relative_testfiles.empty?
      testfiles = @relative_testfiles.map{ |relpath| "#{@testmodule_dir}/#{relpath}" }
    else
      testfiles = Dir.glob("#{@testmodule_dir}/**/*.rb")
    end

    testfiles.each do |testfile|
      begin
        @log.debug "Failure loading file #{testfile}" unless require "#{testfile}"
      rescue Exception => e
        @log.debug "Failed to require testcase #{testfile} #{e.message}"
        @log.debug e.backtrace.join("\n")
      end
    end
  end

  def instantiate_testcase_objects
    testcase_objects_seen = {}
    superclasses = TestCase.decendants

    ObjectSpace.each_object(Class) do |klass|
      superclasses.each do |superclass|
        if (!testcase_objects_seen.has_key?(klass) && !@tests.has_key?(klass)) && klass < superclass
          testfile = klass.instance_method(klass.instance_methods(false).first).source_location.first
          testclass = klass.new(@consoleoutput, testfile, { :platform_label => nil,
                                                            :buildversion => nil,
                                                            :buildname => nil,
                                                            :vespa_version => @vespaversion,
                                                            :basedir => @basedir,
                                                            :nostop => @keeprunning,
                                                            :nostop_if_failure => @keeprunning,
                                                            :configserverhostlist => [],
                                                            :ignore_performance => true,
                                                            :valgrind => false})

          if !@nodelimit || testclass.num_hosts <= @nodelimit
            @tests[klass] = testclass unless @performance != testclass.performance?
          else
            @log.warn "Skipping #{klass.to_s} due to node limit of #{@nodelimit}. Test requires #{testclass.num_hosts}."
            @testclasses_not_run.add(klass)
          end
          testcase_objects_seen[klass] = true
        end
      end
    end
  end

  def scan_for_test_methods
    @tests.each do |klass, object|
      methods = klass.public_instance_methods(true).reject { |m| m !~ /^test_/ }
      if !methods.empty?
        @test_objects[object] = methods
        @log.debug "Test klass=#{klass} file=#{object.testcase_file} methods=#{methods}"
      end
    end
  end

  def compute_nodes_required
    @nodes_required = 0
    @tests.each do |key,value|
      @nodes_required = value.num_hosts if value.num_hosts > @nodes_required
    end
  end

  def run_tests
    thread_pool = Concurrent::FixedThreadPool.new(@node_pool.max_available > 0 ? @node_pool.max_available : 1)

    @backend.initialize_testrun(@test_objects)

    @test_objects.each do |testcase, test_methods|
      # This call blocks until nodes available
      nodes = allocate_nodes(testcase)

      if nodes.empty?
        @log.warn "Not enough nodes available for #{testcase.class} (required #{testcase.num_hosts}"
        @testclasses_not_run.add(testcase.class)
        next
      end

      @log.info "#{testcase.class} allocated nodes #{nodes.map {|n| n.hostname}.join(', ')}."

      thread_pool.post do
        testcase.hostlist = nodes.map {|n| n.hostname}
        @log.info "#{testcase.class} running on hosts #{testcase.hostlist}"

        begin
          test_methods.each do |test_method|
            @log.info "Running #{test_method} from #{testcase.class}"
            @backend.test_running(testcase, test_method)
            test_result = testcase.run([test_method]).first
            @backend.test_finished(testcase, test_method, test_result)
            @log.info "Finished running: #{test_method} from #{testcase.class}"
          end
        rescue Exception => e
          @log.error "Exception #{e.message} "
          raise
        ensure
          @node_pool.free(nodes) unless @keeprunning
        end
      end
    end

    thread_pool.shutdown
    thread_pool.wait_for_termination

    @backend.finalize_testrun
  end

  def allocate_nodes(testcase)
    @log.info "#{testcase.class} requesting nodes"
    wait_until = Time.now.to_i + 60*60
    nodes = @node_pool.allocate(testcase.num_hosts)
    while nodes.empty? and (@node_pool.max_available >= testcase.num_hosts)
      sleep 3
      nodes = @node_pool.allocate(testcase.num_hosts)
      # No new nodes/tests within one hour. Something is wrong.
      break if Time.now.to_i > wait_until
    end
    nodes
  end
end

if __FILE__ == $0
  ENV['VESPA_FACTORY_SYSTEMTESTS_DISABLE_AUTORUN'] = "1"

  options = {}
  options[:testfiles] = []
  OptionParser.new do |opts|
    opts.banner = "Usage: testrunner.rb [options]"
    opts.on("-b", "--basedir DIR", String, "Basedir for test results.") do |basedir|
      options[:basedir] = basedir
    end
    opts.on("-c", "--consoleoutput", "Output test executions on console.") do |c|
      options[:consoleoutput] = c
    end
    opts.on("-f", "--testfile FILE", String, "Ruby test file relative to tests/ path.") do |file|
      options[:testfiles] << file
    end
    opts.on("-k", "--keeprunning", "Keep the node containers running. For inspection/debugging.") do |k|
      options[:keeprunning] = k
    end
    opts.on("-n", "--nodelimit N", Integer, "Only run tests that require no more that N nodes.") do |limit|
      options[:nodelimit] = limit
    end
    opts.on("-p", "--performance", "Run performance tests.") do |p|
      options[:performance] = p
    end
    opts.on("-V", "--vespaversion VERSION", String, "Vespa version to use.") do |version|
      options[:vespaversion] = version
    end
    opts.on("-v", "--verbose", "Run verbosely.") do |v|
      options[:verbose] = v
    end
  end.parse!

  logger = Logger.new(STDOUT)
  logger.level= options[:verbose] ? Logger::DEBUG : Logger::INFO
  logger.datetime_format = '%Y-%m-%d %H:%M:%S'
  logger.formatter = proc do |severity, datetime, progname, msg|
    "[#{datetime}] #{severity} #{msg}\n"
  end

  testrunner = TestRunner.new(logger, options)
  if ! testrunner.run
    logger.error "Some tests failed."
    exit(1)
  end

end
