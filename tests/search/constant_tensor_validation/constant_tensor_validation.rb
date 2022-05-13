# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class ConstantTensorValidationTest < IndexedSearchTest

  def setup
    set_owner("geirst")
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
    assert_match("constant(constant_tensor_1) tensor(x[10], y[8]): file:search/constant_tensor_1.json: Index 10 not within limits of bound dimension 'x'", output)
    assert_match("constant(constant_tensor_2) tensor(x[6]): file:search/constant_tensor_2.json: Tensor label is not a string (VALUE_NUMBER_INT)", output)
    assert_match("constant(constant_tensor_3) tensor(cpp{}, d{}): file:search/constant_tensor_3.json: Tensor dimension 'cd' does not exist", output)
    assert_match("constant(constant_tensor_4) tensor(x{}, y{}): file:search/constant_tensor_4.json: Tensor dimension 'z' does not exist", output)
    assert_match("constant(constant_tensor_5) tensor(x[33], y[10], z[46]): file:search/constant_tensor_5.json: Failed to parse JSON stream", output)
  end

  def teardown
    stop
  end
end
