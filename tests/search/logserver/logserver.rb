# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class LogServer < SearchTest

  def setup
    set_description("Tests that logserver starts up, gets log from logd and writes it to logarchive.")
    set_owner("musum")
  end

  def nightly?
    true
  end

  def test_logarchive
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    verify_log_content(/Transitioning from baseline state 'Down' to 'Up'/, vespa.logserver)
  end

  def verify_log_content(content, logserver)
    matches = assert_log_matches(content, 30, {:use_logarchive => true})
    assert_equal(2, matches)
  end

  def teardown
    stop
  end
end
