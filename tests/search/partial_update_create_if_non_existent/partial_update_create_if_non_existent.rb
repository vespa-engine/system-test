# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class PartialUpdateCreateIfNonExistentTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
  end

  def test_create_if_non_existent
    set_description("Test that partial updates to non-existing documents creates the documents before applying the updates")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    search_node = vespa.search["search"].first

    feed(:file => selfdir + "updates.json")
    assert_updates

    search_node.stop
    search_node.start
    assert_updates

    search_node.trigger_flush
    search_node.stop
    search_node.start
    assert_updates
  end

  def assert_updates
    wait_for_hitcount("sddocname:test", 10)
    assert_hitcount("a_int:10", 1)
    assert_hitcount("a_arr:10", 2)
    assert_hitcount("a_wset:10", 2)
    assert_hitcount("i_str:foo", 1)
    assert_hitcount("i_wset:foo", 2)
    assert_hitcount("a_int:2", 1)
    cmp_fields = ["a_int", "a_arr", "a_wset", "i_str", "i_wset", "documentid"]
    assert_result("sddocname:test&hits=11", selfdir + "result.json", "documentid", cmp_fields)
  end

  def test_increment_update_on_document_that_does_not_exists
    set_description("Test that increment update works on wset for a document that does not exists (see bug 7098648)")
    deploy_app(SearchApp.new.sd(selfdir + "increment/test.sd"))
    start
    feed(:file => selfdir + "increment/docs.json")
    feed(:file => selfdir + "increment/updates.json")
    assert_result("sddocname:test", selfdir + "increment/result.json", "documentid", ["wset"])
  end

  def teardown
    stop
  end

end
