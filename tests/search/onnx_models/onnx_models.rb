# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class OnnxModelsDeployment < IndexedOnlySearchTest

  def setup
    set_description("Test that having a shcema containing some onnx models that are not used in any content cluster works " +
                    " ('foo' and 'baz' in this case). " +
                    "Also test that it works to have global onnx models ('foo' and 'baz' in this case), that are not " +
                    "referenced in content cluster / rank-profiles, but only used by stateless model-evaluation " +
                    "AND having inputs with same name as outputs in a different model.")
    set_owner("hmusum")
  end

  def test_onnx_models_not_used_in_content_cluster
    deploy(selfdir + "app/")
    start
  end

  def teardown
    stop
  end

end
