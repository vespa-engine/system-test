# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_container_test'

class JDiscHandlerLogger < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Deploy and run a JDisc handler that uses all supported logging frameworks.")
    add_bundle_dir(selfdir+"logging-bundle", "logging-bundle")
    deploy("#{selfdir}/app")
    start
  end

  def test_logger_handler
    result = vespa.container["container/0"].search("/LoggerHandler")
    assert_match(Regexp.new("hello from handler"), result.xmldata)
    assert_log_matches(/hello from jcl/)
    assert_log_matches(/hello from jdk/)
    assert_log_matches(/hello from log4j/)
    assert_log_matches(/hello from slf4j/)
  end

  def teardown
    stop
  end

end
