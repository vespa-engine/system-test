# Copyright Vespa.ai. All rights reserved.
# This class stores the result from executing a test_ method in
# a TestCase subclass. Values like number of assertions, errors,
# and the execution log are stored here.
class TestResult

  attr_reader :assertion_count, :failures, :errors, :coredumps, :values, :log
  attr_reader :valgrind_failure, :logfiles, :sanitizer_failure
  attr_accessor :owner, :description, :allow_failure, :failuntil, :allow_ticket
  attr_accessor :starttime, :endtime, :performance_annotation

  # Constructs a new, empty TestResult corresponding to _method_name_.
  def initialize(method_name)
    @method_name = method_name
    @assertion_count = 0
    @failures = []
    @errors = []
    @coredumps = {}
    @valgrind_failure = false
    @sanitizer_failure = false
    @values = []
    @owner = "nobody"
    @description = nil
    @allow_failure = false
    @failuntil = nil
    @allow_ticket = nil
    @log = ""
    @starttime = Time.at(0)
    @endtime = Time.at(0)
    @logfiles = {}
  end

  # Appends a string to the TestResult log.
  def append_log(str)
    @log += str
  end

  # Adds a logfile for this test run
  def add_logfile(name, path)
    @logfiles[name] = path
  end

  # Adds coredumps to this TestResult.
  def add_coredumps(coredumps)
    @coredumps.merge!(coredumps)
  end

  # Records a Failure object.
  def add_failure(failure)
    @failures << failure
  end

  # Records a valgrind Failure object, putting it first in the list of failures.
  def add_valgrind_failure(failure)
    @failures.insert(0, failure)
    @valgrind_failure = true
  end

  def add_sanitizer_failure(failure)
    @failures.insert(0, failure)
    @sanitizer_failure = true
  end

  # Records an Error object.
  def add_error(error)
    @errors << error
  end

  # Records an individual assertion.
  def add_assertion
    @assertion_count += 1
  end

  # Adds a test value to this TestResult.
  def add_test_value(name, value, params={})
    test_value = {}
    test_value[:name] = name
    test_value[:value] = value
    test_value.merge!(params)
    @values << test_value
  end

  # Returns a string contain the recorded runs, assertions,
  # failures and errors in this TestResult.
  def to_s
    "#{assertion_count} assertions, #{failure_count} failures, #{error_count} errors"
  end

  # Returns whether or not this TestResult represents
  # successful completion.
  def passed?
    return @failures.empty? && @errors.empty? && @coredumps.empty?
  end

  # Returns the status of this TestResult.
  def status
    if allow_ticket
      if passed?
        return "allow_success"
      else
        return "allow_failure"
      end
    elsif passed?
      return "success"
    else
      return "failure"
    end
  end

  # Returns the method name stripped of the leading "test_" prefix.
  def name
    return @method_name.to_s.sub(/^test_/, "")
  end

  # Returns the number of failures this TestResult has
  # recorded.
  def failure_count
    return @failures.size
  end

  # Returns the number of errors this TestResult has
  # recorded.
  def error_count
    return @errors.size
  end

  # Returns the duration of the test represented by
  # this TestResult measured in seconds.
  def duration
    return (@endtime.to_i - @starttime.to_i)
  end

end
