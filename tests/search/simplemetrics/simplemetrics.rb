# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SimpleMetrics < SearchTest

  def setup
    set_owner("arnej")
    set_description("Smoke test for simplemetrics implementation")
  end

  def timeout_seconds
    1200
  end

  def test_metrics
    deploy_app(SearchApp.new.
               cluster_name("simplemetrics").
               sd(SEARCH_DATA+"music.sd"))
    start
    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_query_errors("/search/?yql=this+is+not+valid+yql")
    sleep 2
    values = get_qrs_metrics["metrics"]["values"]
    found_searches = false
    found_illegal_parameter = false
    illegal_params_queries = 0
    
    values.each do |value|
      if value["name"] == "queries"
        assert(value["values"]["count"].to_i >= 1, "Incorrectly tracked queries.")
        found_searches = true
      elsif value["name"] == "error.invalid_query_parameter"
        assert(value["values"]["count"].to_i >= 1, "Incorrectly tracked errors.")
        illegal_params_queries = value["values"]["count"].to_i
        found_illegal_parameter = true
      end
    end
    assert(found_searches, "queries missing from metrics")
    assert(found_illegal_parameter, "error.invalid_query_parameter missing from metrics")
    assert_query_errors("/search/?yql=this+is+not+valid+yql+either")
    sleep 2
    found_illegal_parameter = false
    values = get_qrs_metrics["metrics"]["values"]
    values.each do |value|
      if value["name"] == "error.invalid_query_parameter"
        assert(value["values"]["count"].to_i > illegal_params_queries, "Incorrectly tracked errors.")
        found_illegal_parameter = true
      end
    end
    assert(found_illegal_parameter, "error.invalid_query_parameter missing from metrics")
  end

  class StopWatch
    def elapsed
      return Time.now - @before
    end
    def reset
      @before = Time.now
      return self
    end
    def self.start
      new().reset
    end
  end

  def test_oldimplementation
    deploy_app(SearchApp.new.
               config(
                 ConfigOverride.new("metrics.manager").
                 add("reportPeriodSeconds", "60")).
               monitoring("overrideinterval", 60).
               config(
                 ConfigOverride.new("metrics.metrics-presentation").
                 add("slidingwindow", "false")).
               cluster_name("simplemetrics").
               sd(SEARCH_DATA+"music.sd"))
    timer = StopWatch.start
    start
    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    values = get_qrs_metrics["metrics"]
    while timer.elapsed > 60
      puts "too much time (#{timer.elapsed.to_i} / 60 s) passed since start, need to restart qrserver..."
      timer.reset
      vespa.container["default/0"].restart
      wait_for_hitcount("query=sddocname:music", 10)
      values = get_qrs_metrics["metrics"]
    end
    assert(values.size == 0, "Expected no metrics on a fresh system")
    while timer.elapsed < 600
      values = get_qrs_metrics["metrics"]
      break if (values && values.size > 0 && values["values"].size > 0)
      puts "Time passes... #{timer.elapsed.to_i}/600"
      sleep 5
    end
    assert(values.size > 0, "Expected metrics after #{timer.elapsed} seconds")
    assert(values["values"].size > 0, "Expected some metric values after #{timer.elapsed} seconds")
  end

  def get_qrs_metrics
    JSON.parse(vespa.container.values.first.http_get2("/state/v1/metrics").body)
  end

  def teardown
    stop
  end

end
