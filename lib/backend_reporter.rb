
require 'concurrent'
require 'securerandom'

begin
  require 'backend_client'
  BACKEND_CLIENT_OVERLOAD = true
rescue
  BACKEND_CLIENT_OVERLOAD = false
end

class BackendReporter < BackendClient
  def initialize(log, testrun_id = nil)
    @testrun_id = testrun_id ? testrun_id : SecureRandom.urlsafe_base64
    super(log, "/tmp")
  end

  def initialize_testrun(test_objects)
    super(@testrun_id, test_objects)
  end

  def test_running(test_case, method_name)
    super(@testrun_id, test_case, method_name)
  end

  def test_finished(test_case, method_name, test_result)
    super(@testrun_id, test_case, test_result)
  end

  def finalize_testrun
    true
  end

end if BACKEND_CLIENT_OVERLOAD

class BackendReporter
  def initialize(log, testrun_id = nil)
    @test_results = Concurrent::Hash.new
    @test_names = Concurrent::Array.new
    @log = log
    @testrun_id = testrun_id ? testrun_id : SecureRandom.urlsafe_base64
  end

  def initialize_testrun(test_objects)
    test_objects.each do |object, methods|
      methods.each do |method|
        @test_names << "#{object.class}::#{method.to_s}"
      end
    end
  end

  def test_running(test_case, method_name)
    nil
  end

  def test_finished(test_case, method_name, test_result)
    @test_results["#{test_case.class}::#{method_name}"] = test_result
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

end unless BACKEND_CLIENT_OVERLOAD