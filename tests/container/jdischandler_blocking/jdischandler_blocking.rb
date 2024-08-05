# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class JDiscHandlerBlocking < SearchContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Deploy a JDisc handler that prevents shutdown, to " +
                    "ensure that 'vespa-stop-services' is able to kill " +
                    "the yjava_daemon process.")
    add_bundle("#{selfdir}/BlockingHandler.java")
    deploy("#{selfdir}/app")
    start
  end

  def test_blocking_handler
    set_expected_logged(/Timed out waiting for application shutdown/)

    res = search("/BlockMe")
    puts res.xmldata

    qrs = @vespa.container["container/0"]
    pid = qrs.get_pid
    qrs.stop
    cnt = @vespa.adminserver.execute("ps -p #{pid} | wc -l").to_i
    assert_equal(1, cnt)
  end

  def teardown
    stop
  end

end
