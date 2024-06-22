# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class CheckVespaLogTest < VdsTest

  # false, since we want to check log for config server entries too
  def can_share_configservers?
    false
  end

  def setup
    @valgrind=false
    set_owner("vekterli")
    set_description("Check for the presence of log warnings/errors " +
                    "across _all_ Vespa components during a simple " +
                    "startup -> shutdown cycle")
    @time_before_deploy = Time.now
    deploy_app(default_app("simple"))
    @time_before_start = Time.now
    start
  end

  def get_default_log_check_services
    return ['[\\w-]+'] # All components
  end

  def teardown
    @time_before_stop = Time.now
    begin
      stop
    ensure
      puts "\n==========================\n"
      # Everybody loves timings, so let's output some!
      puts("It took #{@time_before_start - @time_before_deploy} seconds " +
           "to deploy the application")
      puts("It took #{@time_test_body_started - @time_before_start} seconds " +
           "to get from start() to actual test function body start")
      puts("It took #{Time.now - @time_before_stop} seconds " +
           "to complete stop()")
      puts "==========================\n\n"
    end
  end

  def test_start_stop_no_unexpected_log_entries
    @time_test_body_started = Time.now
  end
end
