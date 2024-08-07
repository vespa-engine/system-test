# Copyright Vespa.ai. All rights reserved.

require 'factory_http_client'
require 'json'

class FactoryClient
  def initialize(log)
    @http_client = FactoryHttpClient.new
    @log = log
  end

  def initialize_testrun(testrun_id, testcases)
    tests = {}
    tests[:tests] = []
    testcases.each do |testcase, method|
      elems = testcase.testcase_file.split('/')
      if elems.include?('tests-internal')
        i = elems.rindex { |e| e == 'tests-internal' }
        repo = 'systemtests'
      else
        i = elems.rindex { |e| e == 'tests' }
        repo = 'system-test'
      end
      test_source = elems[i..elems.size].join('/')

      tests[:tests] << { :name => "#{testcase.class.name}::#{method.to_s}", :owner => extract_owner(testcase.testcase_file),
                         :repo => "#{repo}", :sourcePath => test_source }
    end

    begin
      response = handle_response(@http_client.request("/factory/v1/testruns/#{testrun_id}/initialize",
                                                      'POST', tests.to_json))
    rescue StandardError => e
      @log.error("Could not initialize testrun #{testrun_id} in Factory.")
      raise e
    end

    test_run_data = { :durations => Hash.new {0},
                      :valgrind => response["useValgrind"] }

    response["testDurations"].each do |test_object|
      test_data = Hash[test_object]
      test_run_data[:durations][test_data["name"]] += test_data["durationSeconds"].to_f
    end

    test_run_data[:durations].default = 1500.0
    test_run_data
  end

  def report_test_running(testrun_id, testcase, testmethod)
    test_name = "#{testcase.class.name}::#{testmethod.to_s}"

    update = { :updatedSeconds => Time.now.to_i, :status => 'running' }

    begin
      handle_response(@http_client.request("/factory/v1/testruns/#{testrun_id}/tests/#{test_name}",
                                           'PUT', update.to_json))
    rescue StandardError => e
      @log.error("Could not report status running for test #{testcase.class}::#{testmethod} to Factory.")
      raise e
    end
  end

  def report_test_finished(testrun_id, testcase, testresult, message, testdata)
    # The testresult.name chops of test_ and we do not have the original method name where this is called
    test_name = "#{testcase.class.name}::test_#{testresult.name}"

    update = { :updatedSeconds => Time.now.to_i, :status => testresult.status, :message => message }
    update[:hasValgrindError => true] if testresult.valgrind_failure
    update[:hasSanitizerError => true] if testresult.sanitizer_failure
    artifacts = { :artifacts => testdata }

    begin
      handle_response(@http_client.request("/factory/v1/testruns/#{testrun_id}/tests/#{test_name}/artifacts",
                                           'POST', artifacts.to_json))

      handle_response(@http_client.request("/factory/v1/testruns/#{testrun_id}/tests/#{test_name}",
                                           'PUT', update.to_json))
    rescue StandardError => e
      @log.error("Could not report status finished for test #{test_name} to Factory.")
      raise e
    end

  end

private
  def handle_response(response)
    unless response.class < Net::HTTPSuccess
      @log.error("Failed to get response from #{response.uri}. Got code #{response.code} with body #{response.body}.")
      raise "Failed getting OK response from factory at #{response.uri}."
    end
    JSON.parse(response.body)
  end

  def extract_owner(source)
    begin
      File.readlines(source).each do |line|
        match = line.match(/^\s*set_owner\(["'](\w+)['"]\)\s*$/)
        return match.captures[0] if match
      end
    rescue
      # The above code might run into misc encoding issues for files
      # without UTF-8 encoding. Empty rescue here for those.
      nil
    end
    'nobody'
  end

end

