# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class LargeDocuments < VdsTest

  def setup
    @valgrind = false
    set_owner("vekterli")

    deploy_app(default_app)
    set_expected_logged(//, :slow_processing => true)
    start
  end

  def timeout_seconds
    1200
  end

  def target_node
    vespa.storage["storage"].distributor["0"]
  end

  def test_largedocuments
     count = 5
     size = 50000000

     target_node.create_dummy_feed(count, size)
     target_node.check_dummy_feed(count, size)
  end

  def teardown
    stop
  end
end

