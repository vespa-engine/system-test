# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'search/tensor_feed/tensor_feed_base.rb'

class TensorModifyUpdateTest < IndexedStreamingSearchTest

  include TensorFeedTestBase

  def setup
    set_owner("geirst")
    @base_dir = selfdir + "tensor_modify_update/"
  end

  def test_modify_updates
    set_description("Test tensor modify updates (replace, add, multiply) in dense, sparse and mixed tensor attributes and fields")
    deploy_app(SearchApp.new.sd(@base_dir + "test.sd").enable_document_api)
    start
    feed_and_wait_for_docs("test", 1, :file => @base_dir + "docs.json")

    query = "query=sddocname:test&format=json&format.tensors=long"
    doc_id = "id:test:test::0"

    feed(:file => @base_dir + "modify_replace.json")
    assert_tensor_fields_after_modify_replace(search_result_document(query, 50))
    assert_tensor_fields_after_modify_replace(get_result_document(doc_id))

    feed(:file => @base_dir + "modify_add.json")
    assert_tensor_fields_after_modify_add(search_result_document(query, 56))
    assert_tensor_fields_after_modify_add(get_result_document(doc_id))

    feed(:file => @base_dir + "modify_multiply.json")
    assert_tensor_fields_after_modify_multiply(search_result_document(query, 77))
    assert_tensor_fields_after_modify_multiply(get_result_document(doc_id))
  end

  def assert_tensor_fields_after_modify_replace(doc)
    assert_dense_tensor_after_modify_replace(doc, "dense_attr")
    assert_dense_tensor_after_modify_replace(doc, "dense_float_attr")
    assert_dense_tensor_after_modify_replace(doc, "dense_field")
    assert_sparse_tensor_after_modify_replace(doc, "sparse_attr")
    assert_sparse_tensor_after_modify_replace(doc, "sparse_float_attr")
    assert_sparse_tensor_after_modify_replace(doc, "sparse_field")
    assert_mixed_tensor_after_modify_replace(doc, "mixed_attr")
    assert_mixed_tensor_after_modify_replace(doc, "mixed_float_attr")
    assert_mixed_tensor_after_modify_replace(doc, "mixed_field")
  end

  def assert_dense_tensor_after_modify_replace(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'0'}, 'value'=>1.0},
                         {'address'=>{'x'=>'1'}, 'value'=>7.0},
                         {'address'=>{'x'=>'2'}, 'value'=>8.0}], doc, name)
  end

  def assert_sparse_tensor_after_modify_replace(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'a'}, 'value'=>1.0},
                         {'address'=>{'x'=>'b'}, 'value'=>7.0},
                         {'address'=>{'x'=>'c'}, 'value'=>8.0}], doc, name)
  end

  def assert_mixed_tensor_after_modify_replace(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'a','y'=>'0'}, 'value'=>1.0},
                         {'address'=>{'x'=>'a','y'=>'1'}, 'value'=>2.0},
                         {'address'=>{'x'=>'b','y'=>'0'}, 'value'=>7.0},
                         {'address'=>{'x'=>'b','y'=>'1'}, 'value'=>8.0}], doc, name)
  end

  def assert_tensor_fields_after_modify_add(doc)
    assert_dense_tensor_after_modify_add(doc, "dense_attr")
    assert_dense_tensor_after_modify_add(doc, "dense_float_attr")
    assert_mixed_tensor_after_modify_add(doc, "mixed_attr")
    assert_mixed_tensor_after_modify_add(doc, "mixed_float_attr")
    assert_sparse_tensor_after_modify_add_with_create_true(doc, "sparse_create_attr")
    assert_sparse_tensor_after_modify_add_with_create_true(doc, "sparse_create_field")
    assert_dense_null_tensor_after_modify_add_with_create_true(doc, "dense_null_create_attr")
    assert_dense_null_tensor_after_modify_add_with_create_true(doc, "dense_null_create_field")
  end

  def assert_dense_tensor_after_modify_add(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'0'}, 'value'=>6.0},
                         {'address'=>{'x'=>'1'}, 'value'=>7.0},
                         {'address'=>{'x'=>'2'}, 'value'=>8.0}], doc, name)
  end

  def assert_mixed_tensor_after_modify_add(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'a','y'=>'0'}, 'value'=>1.0},
                         {'address'=>{'x'=>'a','y'=>'1'}, 'value'=>3.0},
                         {'address'=>{'x'=>'b','y'=>'0'}, 'value'=>7.0},
                         {'address'=>{'x'=>'b','y'=>'1'}, 'value'=>8.0}], doc, name)
  end

  def assert_sparse_tensor_after_modify_add_with_create_true(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'a'}, 'value'=>1.0},
                         {'address'=>{'x'=>'b'}, 'value'=>7.0},
                         {'address'=>{'x'=>'c'}, 'value'=>6.0}], doc, name)
  end

  def assert_dense_null_tensor_after_modify_add_with_create_true(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'0'}, 'value'=>0.0},
                         {'address'=>{'x'=>'1'}, 'value'=>3.0}], doc, name)
  end

  def assert_tensor_fields_after_modify_multiply(doc)
    assert_dense_tensor_after_modify_multiply(doc, "dense_attr")
    assert_dense_tensor_after_modify_multiply(doc, "dense_float_attr")
    assert_mixed_tensor_after_modify_multiply(doc, "mixed_attr")
    assert_mixed_tensor_after_modify_multiply(doc, "mixed_float_attr")
  end

  def assert_dense_tensor_after_modify_multiply(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'0'}, 'value'=>18.0},
                         {'address'=>{'x'=>'1'}, 'value'=>7.0},
                         {'address'=>{'x'=>'2'}, 'value'=>8.0}], doc, name)
  end

  def assert_mixed_tensor_after_modify_multiply(doc, name)
    assert_tensor_field([{'address'=>{'x'=>'a','y'=>'0'}, 'value'=>1.0},
                         {'address'=>{'x'=>'a','y'=>'1'}, 'value'=>12.0},
                         {'address'=>{'x'=>'b','y'=>'0'}, 'value'=>7.0},
                         {'address'=>{'x'=>'b','y'=>'1'}, 'value'=>8.0}], doc, name)
  end

  def teardown
    stop
  end

end
