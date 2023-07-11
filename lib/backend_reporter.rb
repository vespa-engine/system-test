# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'concurrent'

begin
  require 'backend_client'
  BACKEND_CLIENT_OVERRIDE = true
rescue LoadError
  BACKEND_CLIENT_OVERRIDE = false
end

class BackendReporter < BackendClient
  def initialize(testrun_id, basedir, log)
    super(testrun_id, basedir, log)
    @testrun_id = testrun_id
  end

  def initialize_testrun(test_objects)
    super(test_objects)
  end

  def sort_testcases(test_objects)
    super(test_objects)
  end

  def use_valgrind
    super()
  end

  def test_running(test_case, method_name)
    super(test_case, method_name)
  end

  def test_finished(test_case, test_result)
    super(test_case, test_result)
  end

  def finalize_testrun
    true
  end

end if BACKEND_CLIENT_OVERRIDE

class BackendReporter
  def initialize(testrun_id, basedir, log)
    @testrun_id = testrun_id
    @basedir = basedir
    @log = log
    @test_results = Concurrent::Hash.new
    @test_names = Concurrent::Array.new
    @mutex = Mutex.new

    addr = ":#{TestBase::DRUBY_REPORTER_PORT}"
    endpoint = DrbEndpoint.new(addr)
    server = endpoint.start_service(for_object: self)
    uri = URI(server.uri)

    @log.debug "Backend reporter endpoint: #{uri.host}:#{uri.port} (#{endpoint.secure? ? 'secure' : 'INSECURE'})"

    reporter_up = false
    endtime = Time.now.to_i + 10
    while Time.now.to_i < endtime
      begin
        TCPSocket.new("127.0.0.1", TestBase::DRUBY_REPORTER_PORT).close
        reporter_up = true
        break
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      end
      sleep 2
    end
    if ! reporter_up
      raise "Could not connect to reporter at #{uri.host}:#{uri.port}"
    end
  end

  def initialize_testrun(test_objects)
    test_objects.each do |object, method|
      @test_names << "#{object.class}::#{method.to_s}"
    end
  end

  def sort_testcases(test_objects)
    test_objects
  end

  def use_valgrind
    false
  end

  def test_running(test_case, method_name)
    nil
  end

  # This method can be called from a different process or reactor on the same host
  def test_finished(test_case, test_result)
    endpoint = DrbEndpoint.new("localhost:#{TestBase::DRUBY_REPORTER_PORT}")
    reporter = endpoint.create_client(with_object: nil)
    reporter.report_test_finished("#{test_case.class}::test_#{test_result.name}", test_result)
  end

  def report_test_finished(test_class_and_method, test_result)
    @mutex.synchronize do
      # The testresult.name chops of test_ and we do not have the original method name where this is called
      @test_results[test_class_and_method] = test_result
    end
  end

  def finalize_testrun
    successful_tests = @test_results.select { |name, result| result.passed? }
    failed_tests = @test_results.reject { |name, result| result.passed? }
    @log.info "#################"
    @log.info "Successful tests:"
    successful_tests.each { |key, value| @log.info "  #{key}   #{value.to_s}" }
    @log.info "#################"
    @log.info "Failed tests:"
    failed_tests.each { |key, value| @log.info "  #{key}   #{value.to_s}" }
    @log.info "#################"

    tests_not_run = @test_names.to_set ^ @test_results.map { |name, result| name}.to_set
    unless tests_not_run.empty?
      @log.info "#################"
      @log.info "Tests not run:"
      tests_not_run.each { |klass| @log.info "  #{klass}" }
      @log.info "#################"
    end
    failed_tests.empty?
  end

end unless BACKEND_CLIENT_OVERRIDE
