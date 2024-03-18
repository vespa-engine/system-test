# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class ProtonPrepareRestartTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
  end

  def test_proton_prepare_restart_command
    set_description("Test that vespa-proton-cmd prepareRestart command flushes components")
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    # Needed for logging messages that are verified later in this test
    vespa.adminserver.logctl("searchnode:proton.flushengine.prepare_restart_flush_strategy", "debug=on,spam=on")
    start
    feed_and_wait_for_docs("test", 100, :file => "#{selfdir}/docs.4.json")
    vespa.search["search"].first.prepare_restart

    expected_flush_targets = ['test.0.ready.attribute.flush.iattr',
                              'test.0.ready.attribute.flush.sattr',
                              'test.0.ready.documentmetastore.flush',
                              'test.0.ready.memoryindex.flush',
                              'test.0.ready.summary.flush',
                              'test.1.removed.documentmetastore.flush',
                              'test.1.removed.summary.flush',
                              'test.2.notready.documentmetastore.flush',
                              'test.2.notready.summary.flush']
    assert_targets_flushed(expected_flush_targets)
  end

  def assert_targets_flushed(flush_targets)
    flush_targets.each do |flush_target|
      assert_log_matches(/flush.start.*#{flush_target}/)
      assert_log_matches(/flush.complete.*#{flush_target}/)
    end
  end

  def teardown
    stop
  end
end
