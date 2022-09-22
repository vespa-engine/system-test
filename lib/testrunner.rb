# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
require 'securerandom'

class TestRunner

  def initialize(logger, basedir, node_allocator, **options)
    @log = logger
    @basedir = basedir
    @node_allocator = node_allocator

    @buildname = options[:buildname]
    @buildversion = options[:buildversion]
    @configservers = options[:configservers] ? options[:configservers] : []
    @consoleoutput = options[:consoleoutput] ? options[:consoleoutput] : false
    @ignore_performance = options[:ignore_performance] ? options[:ignore_performance] : true
    @keeprunning = options[:keeprunning] ? options[:keeprunning] : false
    @nodelimit = options[:nodelimit]
    @performance = options[:performance] ? options[:performance] : false
    @platform_label = options[:platform_label]
    @relative_testfiles = options[:testfiles] ? options[:testfiles] : []
    @testmodule_dirs = options[:testmoduledirs] ? options[:testmoduledirs] : ["#{__dir__}/../tests", "#{__dir__}/../tests-internal"]
    @testrun_id = options[:testrunid] ? options[:testrunid] : SecureRandom.urlsafe_base64
    @vespaversion = options[:vespaversion] ? options[:vespaversion] : "8-SNAPSHOT"
    @wait_for_nodes = options[:nodewait] ? options[:nodewait] : 60
    @dns_settle_time = options[:dns_settle_time] ? options[:dns_settle_time] : 0

    @backend = BackendReporter.new(@testrun_id, @basedir, @log)
    @backend.set_use_sanitizer(options[:sanitizer]) if options[:sanitizer]
  end

  def initialize_run_dependent_fields
    @tests = {}
    @test_objects = {}
    @nodes_required = 0
  end

  def run
    initialize_run_dependent_fields
    require_testcases
    instantiate_testcase_objects
    compute_nodes_required

    wait_until = Time.now.to_i + @wait_for_nodes
    while Time.now.to_i < wait_until && @node_allocator.max_available < @nodes_required
      sleep 1
      @log.info "Waiting for at least #{@nodes_required} to become available. Currently #{@node_allocator.max_available}."
    end

    if @node_allocator.max_available >= @nodes_required
      @log.info "Running #{@test_objects.size} test cases."
      run_tests
    else
      @log.error "Tests require minimum #{@nodes_required}, but found only #{@node_allocator.max_available}. Exiting."
      false
    end
  end

  private

  def require_testcases
    testfiles = []
    if not @relative_testfiles.empty?
      @testmodule_dirs.each do |dir|
        @relative_testfiles.each do |file|
          testfile = "#{dir}/#{file}"
          testfiles << testfile if File.exist?(testfile)
        end
      end
    else
      @testmodule_dirs.each do |dir|
        testfiles.concat(Dir.glob("#{dir}/**/*.rb"))
      end
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
    superclasses = TestCase.decendants

    ObjectSpace.each_object(Class) do |klass|
      superclasses.each do |superclass|
        if !@tests.has_key?(klass) && klass < superclass
          testfile = klass.instance_method(klass.instance_methods(false).first).source_location.first

          @tests[klass] = []

          scan_for_test_methods(klass, testfile).each do |method|
            testclass = klass.new(@consoleoutput, testfile, { :platform_label => @platform_label,
                                                              :buildversion => @buildversion,
                                                              :buildname => @buildname,
                                                              :vespa_version => @vespaversion,
                                                              :basedir => @basedir,
                                                              :nostop => @keeprunning,
                                                              :nostop_if_failure => @keeprunning,
                                                              :configserverhostlist => [],
                                                              :ignore_performance => @ignore_performance })

            # No need to do more as performance is a test class property
            break if @performance != testclass.performance?

            # No need to do more if we have a node limit and test class requires above limit
            if @nodelimit && testclass.num_hosts > @nodelimit
              @log.warn "Skipping #{klass.to_s} due to node limit of #{@nodelimit}. Test requires #{testclass.num_hosts}."
              break
            end

            # Use shared config servers if we have them configured and test case can use them
            if testclass.can_share_configservers? && @configservers.any?
              testclass.configserverhostlist = @configservers
              testclass.use_shared_configservers = true
            end

            @tests[klass] << testclass
            @test_objects[testclass] = method
          end
        end
      end
    end
  end

  def scan_for_test_methods(klass, testcase_file)
    methods = klass.public_instance_methods(true).reject { |m| m !~ /^test_/ }
    @log.debug "Test klass=#{klass} file=#{testcase_file} methods=#{methods}"
    methods
  end

  def compute_nodes_required
    @nodes_required = 0
    @tests.each do |key,objects|
      unless objects.empty?
        @nodes_required = objects.first.num_hosts if objects.first.num_hosts > @nodes_required
      end
    end
  end

  def run_tests
    max_threads = [@node_allocator.max_available, @nodelimit ? @nodelimit : 0, 1].max
    @log.debug("Running tests with a thread pool of #{max_threads} threads.")
    thread_pool = Concurrent::FixedThreadPool.new(max_threads)

    @backend.initialize_testrun(@test_objects)

    @backend.sort_testcases(@test_objects).each do |testcase, test_method|

      testcase.valgrind = @backend.use_valgrind ? "all" : nil
      testcase.sanitizer = @backend.use_sanitizer

      thread_pool.post do
        @log.info "#{testcase.class}::#{test_method.to_s} requesting nodes"

        begin
          start_allocate = Time.now.to_i
          nodes = @node_allocator.allocate(testcase.num_hosts, 3600)
          waited_for = Time.now.to_i - start_allocate
        rescue StandardError => e
          @log.error("Not enough nodes were available, could not run #{testcase.class} (required #{testcase.num_hosts}). Exception received #{e.message}")
          next
        end

        @log.info "#{testcase.class}::#{test_method.to_s} allocated nodes #{nodes.join(', ')} after #{waited_for} seconds."

        begin
          testcase.hostlist = nodes
          if @dns_settle_time > 0
            # Sleep @dns_settle_time seconds to reduce probability for DNS errors when lookup up nodes in swarm
            @log.info "Settling network (max #{@dns_settle_time} seconds) before running #{test_method} from #{testcase.class}"
            end_by = Time.now + @dns_settle_time
            begin
              testcase.hostlist.each { |host| Socket.gethostbyname(host) }
            rescue SocketError
              sleep 1
              retry if Time.now < end_by
            end
          end
          @log.info "Running #{test_method} from #{testcase.class} on #{testcase.hostlist}"
          @backend.test_running(testcase, test_method)
          test_result = testcase.run([test_method]).first

          # So our test failed in some way and one or more nodes are dead. We will retry.
          raise TestNodeFailure unless test_result.passed? || @node_allocator.all_alive?(nodes)

          @backend.test_finished(testcase, test_result)
          @log.info "Finished running: #{test_method} from #{testcase.class}"
        rescue TestNodeFailure
          @log.warn("Node failures observed when running #{testcase.class}::#{test_method.to_s}. Retrying.")
          @node_allocator.free(nodes)
          nodes = @node_allocator.allocate(testcase.num_hosts, 3600)
          @log.info "#{testcase.class}::#{test_method.to_s} allocated nodes #{nodes.join(', ')}"
          retry
        rescue StandardError => e
          @log.error "Exception #{e.message} "
          raise
        ensure
          @node_allocator.free(nodes) unless @keeprunning
        end
      end
    end

    thread_pool.shutdown
    thread_pool.wait_for_termination

    @backend.finalize_testrun
  end

end

if __FILE__ == $0
  ENV['VESPA_FACTORY_SYSTEMTESTS_DISABLE_AUTORUN'] = "1"

  options = {}
  options[:testfiles] = []
  options[:configservers] = []
  OptionParser.new do |opts|
    opts.banner = "Usage: testrunner.rb [options]"
    opts.on("-b", "--basedir DIR", String, "Basedir for test results.") do |basedir|
      options[:basedir] = basedir
    end
    opts.on("-c", "--configserver SERVER", String, "Shared configserver for tests that support it.") do |server|
      options[:configservers] << server
    end
    opts.on("-d", "--dns-settle-time SECONDS", Integer, "Wait at start of test for dns to settle.") do |seconds|
      options[:dns_settle_time] = seconds
    end
    opts.on("-f", "--testfile FILE", String, "Ruby test file relative to tests/ path.") do |file|
      options[:testfiles] << file
    end
    opts.on("-i", "--testid ID", "Testrun id. Automatically generated if not specified.") do |id|
      options[:testrunid] = id
    end
    opts.on("-k", "--keeprunning", "Keep the node containers running. For inspection/debugging.") do |k|
      options[:keeprunning] = k
    end
    opts.on("-n", "--nodelimit N", Integer, "Only run tests that require no more that N nodes.") do |limit|
      options[:nodelimit] = limit
    end
    opts.on("-o", "--consoleoutput", "Output test executions on console.") do |c|
      options[:consoleoutput] = c
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
    opts.on("-w", "--nodewait SECONDS", Integer, "Wait for enough nodes for this many seconds.") do |seconds|
      options[:nodewait] = seconds
    end
    opts.on("--sanitizer SANITIZER", String, "Santizer, one of 'address', 'thread', 'undefined'") do |sanitizer|
      options[:sanitizer] = sanitizer
    end
  end.parse!

  logger = Logger.new(STDOUT)
  logger.level= options[:verbose] ? Logger::DEBUG : Logger::INFO
  logger.datetime_format = '%Y-%m-%d %H:%M:%S'
  logger.formatter = proc do |severity, datetime, progname, msg|
    "[#{datetime}] #{severity} #{msg}\n"
  end

  testrunner = TestRunner.new(logger, options[:basedir], TestNodePool.new(logger), **options)
  unless testrunner.run
    logger.error "Some tests failed."
    exit(1)
  end

end
