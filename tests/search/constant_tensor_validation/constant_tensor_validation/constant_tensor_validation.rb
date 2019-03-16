# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class ConstantTensorValidationTest < IndexedSearchTest
  def setup
    set_owner("nobody")
  end

  def create_app(tensordir:)
    SearchApp.new.
        sd("#{selfdir}/simple.sd").
        search_dir("#{selfdir}/#{tensordir}")
  end

  def test_constant_tensor_validation_valid
    set_description("Test that constant tensor validation feature does not fail deploy with valid constant tensors")
    deploy_app(create_app(tensordir: "valid_tensors"))
    start
  end
  
  def test_constant_tensor_validation_invalid
    set_description("Test that constant tensor validation feature fails deploy with invalid constant tensors")
    begin
        deploy_app(create_app(tensordir: "invalid_tensors"))
        start
    rescue ExecuteError => e
        puts "ExecuteError: #{e}: '#{e.output}'"
        assert_failed_deploy(e.output)
        return
    end

    fail "Deploy should fail"
  end

  def assert_failed_deploy(output)
    assert_match("Ranking constant \"constant_tensor_1\" (search/constant_tensor_1.json): Coordinate \"10\" not within limits of bounded dimension x", output)
    assert_match("Ranking constant \"constant_tensor_2\" (search/constant_tensor_2.json): Tensor coordinate is not a string (VALUE_NUMBER_INT)", output)
    assert_match("Ranking constant \"constant_tensor_3\" (search/constant_tensor_3.json): Tensor dimension \"cd\" does not exist", output)
    assert_match("Ranking constant \"constant_tensor_4\" (search/constant_tensor_4.json): Tensor dimension \"z\" does not exist", output)
    assert_match("Ranking constant \"constant_tensor_5\" (search/constant_tensor_5.json): Failed to parse JSON stream", output)
  end

  def teardown
    stop
  end
end
