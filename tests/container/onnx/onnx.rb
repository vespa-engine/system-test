# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class OnnxInContainerTest < SearchContainerTest

  def setup
    @valgrind = false
    set_owner("lesters")
    set_description("Verify that a ONNX model can evaluated with ONNX RT in container.")
  end

  def test_onnx_rt_in_container
    add_bundle_dir(selfdir + "onnx_bundle", "onnx")
    deploy(selfdir + "app")
    start

    result = search("query=test")
    result.hit.each { |hit|
      if hit.field["model"] == "mul"
        assert_equal(6, hit.field["result"].to_f)
      end
      if hit.field["model"] == "add"
        assert_equal(5, hit.field["result"].to_f)
      end
    }

  end

  def teardown
    stop
  end

end
