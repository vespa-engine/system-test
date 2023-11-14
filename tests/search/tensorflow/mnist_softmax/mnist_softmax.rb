# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MnistSoftmaxOnnxAndTensorFlow < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("TensorFlow and Onnx model should produce equals results.")
  end

  def tensorflow_test_mnist_softmax
    deploy(selfdir + "app/")
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "documents.xml")
    assert_relevancy("query=sddocname:test&ranking=tensorflow", 0.6273491382598877)
    assert_relevancy("query=sddocname:test&ranking=onnx", 0.6273491382598877)
    assert_relevancy("query=sddocname:test&ranking=onnx_vespa", 0.6273491382598877)
    assert_relevancy("query=sddocname:test&ranking=tf2onnx", 0.6273491382598877)
   end

  def teardown
    stop
  end

end
