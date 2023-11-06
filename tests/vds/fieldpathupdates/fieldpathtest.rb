# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'
require 'gatewayxmlparser'

class FieldPath < VdsTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app("banana"))
    start
    feedfile(selfdir + "feed_complex.xml")
  end

  def teardown
    stop
  end

  def visit_with_removed_timestamp
    output = vespa.storage["storage"].storage["0"].execute("vespa-visit --xmloutput")
    output.gsub(/\s*lastmodifiedtime="(\d+)"\s*/, "")
  end

  def do_test_feed_and_update(feed_file, correct_file)
    feedfile(selfdir + feed_file)
    output = GatewayXMLParser.new(visit_with_removed_timestamp).documents
    wanted = GatewayXMLParser.new(File.read(selfdir + correct_file)).documents
    assert_equal(wanted, output)
  end

  def test_assign
    do_test_feed_and_update("assign_update.xml", "assign_update_correct.xml")
  end

  def test_add
    do_test_feed_and_update("add_update.xml", "add_update_correct.xml")
  end

  def test_remove
    do_test_feed_and_update("remove_update.xml", "remove_update_correct.xml")
  end

end
