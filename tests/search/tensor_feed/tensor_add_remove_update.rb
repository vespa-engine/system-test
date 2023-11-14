# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'search/tensor_feed/tensor_feed_base.rb'

class TensorAddRemoveUpdateTest < IndexedStreamingSearchTest

  include TensorFeedTestBase

  def setup
    set_owner("geirst")
    @base_dir = selfdir + "tensor_add_remove_update/"
  end

  def test_add_and_remove_updates
    set_description("Test tensor add and remove updates on sparse and mixed tensor attributes and fields")
    deploy_app(SearchApp.new.sd(@base_dir + "test.sd").enable_document_api.
               config(ConfigOverride.new("vespa.config.search.core.proton").
                      add("tensor_implementation", "FAST_VALUE")))
    start
    feed_and_wait_for_docs("test", 1, :file => @base_dir + "docs.json")

    query = "query=sddocname:test&format=json&format.tensors=long"
    doc_id = "id:test:test::0"

    feed(:file => @base_dir + "add_update.json")
    assert_tensor_fields_after_add_update(search_result_document(query, 14 + 29 + 8))
    assert_tensor_fields_after_add_update(get_result_document(doc_id))

    feed(:file => @base_dir + "remove_update.json")
    assert_tensor_fields_after_remove_update(search_result_document(query, 7 + 15 + 3))
    assert_tensor_fields_after_remove_update(get_result_document(doc_id))

    feed(:file => @base_dir + "remove_add_combined.json")
    assert_tensor_fields_after_remove_add_combined(search_result_document(query, 7 + 15 + 5))
    assert_tensor_fields_after_remove_add_combined(get_result_document(doc_id))
  end

  def assert_tensor_fields_after_add_update(doc)
    exp_sparse = [{'address'=>{'x'=>'a'}, 'value'=>2.0},
                  {'address'=>{'x'=>'b'}, 'value'=>5.0},
                  {'address'=>{'x'=>'c'}, 'value'=>7.0}]
    assert_tensor_field(exp_sparse, doc, "sparse_attr")
    assert_tensor_field(exp_sparse, doc, "sparse_field")

    exp_mixed = [{'address'=>{'x'=>'a','y'=>'0'}, 'value'=>1.0},
                 {'address'=>{'x'=>'a','y'=>'1'}, 'value'=>2.0},
                 {'address'=>{'x'=>'b','y'=>'0'}, 'value'=>5.0},
                 {'address'=>{'x'=>'b','y'=>'1'}, 'value'=>6.0},
                 {'address'=>{'x'=>'c','y'=>'0'}, 'value'=>7.0},
                 {'address'=>{'x'=>'c','y'=>'1'}, 'value'=>8.0}]
    assert_tensor_field(exp_mixed, doc, "mixed_attr")
    assert_tensor_field(exp_mixed, doc, "mixed_field")

    exp_adv_mixed = [{'address'=>{'x'=>'a','y'=>'c','z'=>'0'}, 'value'=>1.0},
                     {'address'=>{'x'=>'a','y'=>'d','z'=>'0'}, 'value'=>3.0},
                     {'address'=>{'x'=>'b','y'=>'c','z'=>'0'}, 'value'=>4.0}]
    assert_tensor_field(exp_adv_mixed, doc, "adv_mixed_attr")
    assert_tensor_field(exp_adv_mixed, doc, "adv_mixed_field")

    assert_tensor_field([{'address'=>{'x'=>'b'}, 'value'=>5.0},
                         {'address'=>{'x'=>'c'}, 'value'=>7.0}], doc, "non_existing_sparse_attr")
  end

  def assert_tensor_fields_after_remove_update(doc)
    exp_sparse = [{'address'=>{'x'=>'c'}, 'value'=>7.0}]
    assert_tensor_field(exp_sparse, doc, "sparse_attr")
    assert_tensor_field(exp_sparse, doc, "sparse_field")

    exp_mixed = [{'address'=>{'x'=>'c','y'=>'0'}, 'value'=>7.0},
                 {'address'=>{'x'=>'c','y'=>'1'}, 'value'=>8.0}]
    assert_tensor_field(exp_mixed, doc, "mixed_attr")
    assert_tensor_field(exp_mixed, doc, "mixed_field")

    exp_adv_mixed = [{'address'=>{'x'=>'a','y'=>'d','z'=>'0'}, 'value'=>3.0}]
    assert_tensor_field(exp_adv_mixed, doc, "adv_mixed_attr")
    assert_tensor_field(exp_adv_mixed, doc, "adv_mixed_field")
  end

  def assert_tensor_fields_after_remove_add_combined(doc)
    exp_adv_mixed = [{'address'=>{'x'=>'a','y'=>'e','z'=>'0'}, 'value'=>5.0}]
    assert_tensor_field(exp_adv_mixed, doc, "adv_mixed_attr")
    assert_tensor_field(exp_adv_mixed, doc, "adv_mixed_field")
  end

  def teardown
    stop
  end

end
