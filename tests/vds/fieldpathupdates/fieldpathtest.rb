# Copyright Vespa.ai. All rights reserved.
require 'vds_test'
require 'gatewayxmlparser'

class FieldPath < VdsTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app("banana"))
    start
    feedfile(selfdir + "feed_complex.json")
  end

  def teardown
    stop
  end

  def visit
    output = vespa.storage["storage"].storage["0"].execute("vespa-visit")
  end

  def do_test_feed_and_update(feed_file, correct_file)
    feedfile(selfdir + feed_file)
    output = GatewayXMLParser.new(visit).documents
    wanted = GatewayXMLParser.new(File.read(selfdir + correct_file)).documents
    assert_equal(wanted, output)
  end

  def test_assign
    do_test_feed_and_update("assign_update.json", "assign_update_correct.json")
  end

  def no_test_add
    do_test_feed_and_update("add_update.json", "add_update_correct.json")
  end

  def no_test_remove
    do_test_feed_and_update("remove_update.json", "remove_update_correct.json")
  end

end
