# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesTensorAttributeTest < SearchTest

  include SchemaChangesBase

  def setup
    set_owner("geirst")
  end

  def assert_tensor_content(exp_tensor, exp_relevancy)
    result = search("query=sddocname:test&format=json&format.tensors=long")
    assert_tensor_field([{'address'=>{'x'=>'0'}, 'value'=>exp_tensor[0]},
                         {'address'=>{'x'=>'1'}, 'value'=>exp_tensor[1]}], result, "t1")
    assert_relevancy(result, exp_relevancy)
  end

  def test_add_and_remove_attribute_aspect
    set_description("Test that attribute aspect can be added and removed on a tensor field")
    @test_dir = selfdir + "add_and_remove_tensor_attribute/"
    deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    assert_tensor_content([2, 3], 5)

    # Remove attribute aspect (which is delayed)
    remove_attribute_aspect("test.1.sd")
    assert_tensor_content([2, 3], 0)
    feed(:file => @test_dir + "feed.1.json")
    assert_tensor_content([4, 3], 0)

    # Activate removal of attribute aspect
    activate_attribute_aspect(1)
    assert_remove_reprocess_event_logs("t1", 1)
    assert_tensor_content([4, 3], 0)

    # Add attribute aspect (which is delayed)
    add_attribute_aspect("test.0.sd")
    assert_tensor_content([4, 3], 0)
    feed(:file => @test_dir + "feed.2.json")
    assert_tensor_content([5, 3], 0)

    # Activate adding of attribute aspect
    activate_attribute_aspect(1)
    assert_add_reprocess_event_logs("t1", 1)
    assert_tensor_content([5, 3], 8)
    feed(:file => @test_dir + "feed.3.json")
    assert_tensor_content([6, 3], 9)
  end

  def teardown
    stop
  end

end
