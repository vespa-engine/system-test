# Copyright Vespa.ai. All rights reserved.
require 'search_test'

class LogServer < SearchTest

  def setup
    set_owner("musum")
  end

  def test_logarchive
    set_description("Tests that logserver starts up, gets log from logd and writes it to logarchive.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    sleep 2
    verify_log_content(/Transitioning from baseline state 'Down' to 'Up'/)
  end

  def test_log_forwarding_turned_off
    set_description("Tests that log forwarding from logd to logserver can be turned off.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA + "music.sd")
               .config(ConfigOverride.new("cloud.config.log.logd")
                       .add("logserver", ConfigValue.new("use", "false"))))
    start
    sleep 2
    assert_log_not_matches(/Transitioning from baseline state 'Down' to 'Up'/, {:use_logarchive => true})
  end

  def test_full_logarchive
    set_description("Tests that logserver starts up, gets full log from logd and writes it to logarchive.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").config(logd_config_override))
    start
    sleep 2
    loglines_archived = get_loglines(:use_logarchive => true)
    loglines_orig = get_loglines
    puts "Archived #{loglines_archived.size} of #{loglines_orig.size} log lines"
    assert(loglines_orig.size >= loglines_archived.size)
    compare_lines(loglines_orig, loglines_archived)
  end

  def verify_log_content(content)
    matches = assert_log_matches(content, 30, {:use_logarchive => true})
    assert_equal(2, matches)
  end

  def add_loglevel_forward(cfg, level, forward)
    cfg.add("loglevel", ConfigValue.new(level, ConfigValue.new("forward", forward)))
  end

  def logd_config_override
    cfg = ConfigOverride.new("cloud.config.log.logd")
    add_loglevel_forward(cfg, "event", true)
    add_loglevel_forward(cfg, "debug", true)
    add_loglevel_forward(cfg, "spam", true)
    cfg
  end

  def get_loglines(args = {})
    log = ""
    vespa.logserver.get_vespalog(args) { |data|
      log << data
      nil
    }
    log.split("\n")
  end

  def compare_lines(expected_lines, actual_lines)
    actual_lines.size.times do |i|
      assert_equal(expected_lines[i], actual_lines[i])
    end
  end

  def teardown
    stop
  end

end
