# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'search/tensor_feed/tensor_feed_base.rb'

class TensorAddRemoveUpdateTest < SearchTest

  include TensorFeedTestBase

  def setup
    set_owner("geirst")
    @base_dir = selfdir + "tensor_add_remove_update/"
  end

  def test_add_and_remove_updates
    set_description("Test tensor add and remove updates on sparse and mixed tensor attributes and fields")
    deploy_app(SearchApp.new.sd(@base_dir + "test.sd").enable_http_gateway)
    start
    feed_and_wait_for_docs("test", 1, :file => @base_dir + "docs.json", :json => true)

    query = "query=sddocname:test&format=json"
    doc_id = "id:test:test::0"

    feed(:file => @base_dir + "add_update.json", :json => true)
    assert_tensor_fields_after_add_update(search_result_document(query, 43))
    assert_tensor_fields_after_add_update(get_result_document(doc_id))

    feed(:file => @base_dir + "remove_update.json", :json => true)
    assert_tensor_fields_after_remove_update(search_result_document(query, 22))
    assert_tensor_fields_after_remove_update(get_result_document(doc_id))
  end

  def assert_tensor_fields_after_add_update(doc)
    assert_tensor_field([{'address'=>{'x'=>'a'}, 'value'=>2.0},
                         {'address'=>{'x'=>'b'}, 'value'=>5.0},
                         {'address'=>{'x'=>'c'}, 'value'=>7.0}], doc, "sparse_attr")

    assert_tensor_field([{'address'=>{'x'=>'a'}, 'value'=>2.0},
                         {'address'=>{'x'=>'b'}, 'value'=>5.0},
                         {'address'=>{'x'=>'c'}, 'value'=>7.0}], doc, "sparse_field")

    assert_tensor_field([{'address'=>{'x'=>'a','y'=>'0'}, 'value'=>1.0},
                         {'address'=>{'x'=>'a','y'=>'1'}, 'value'=>2.0},
                         {'address'=>{'x'=>'b','y'=>'0'}, 'value'=>5.0},
                         {'address'=>{'x'=>'b','y'=>'1'}, 'value'=>6.0},
                         {'address'=>{'x'=>'c','y'=>'0'}, 'value'=>7.0},
                         {'address'=>{'x'=>'c','y'=>'1'}, 'value'=>8.0}], doc, "mixed_attr")

    assert_tensor_field([{'address'=>{'x'=>'a','y'=>'0'}, 'value'=>1.0},
                         {'address'=>{'x'=>'a','y'=>'1'}, 'value'=>2.0},
                         {'address'=>{'x'=>'b','y'=>'0'}, 'value'=>5.0},
                         {'address'=>{'x'=>'b','y'=>'1'}, 'value'=>6.0},
                         {'address'=>{'x'=>'c','y'=>'0'}, 'value'=>7.0},
                         {'address'=>{'x'=>'c','y'=>'1'}, 'value'=>8.0}], doc, "mixed_field")
  end

  def assert_tensor_fields_after_remove_update(doc)
    assert_tensor_field([{'address'=>{'x'=>'c'}, 'value'=>7.0}], doc, "sparse_attr")
    assert_tensor_field([{'address'=>{'x'=>'c'}, 'value'=>7.0}], doc, "sparse_field")

    assert_tensor_field([{'address'=>{'x'=>'c','y'=>'0'}, 'value'=>7.0},
                         {'address'=>{'x'=>'c','y'=>'1'}, 'value'=>8.0}], doc, "mixed_field")

    assert_tensor_field([{'address'=>{'x'=>'c','y'=>'0'}, 'value'=>7.0},
                         {'address'=>{'x'=>'c','y'=>'1'}, 'value'=>8.0}], doc, "mixed_field")
  end

  def teardown
    stop
  end

end
