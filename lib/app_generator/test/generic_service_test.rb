# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'
require 'app_generator/generic_service'
require 'environment'
require_relative 'assertion_utils'

class GenericServiceAppGenTest < Test::Unit::TestCase
  include AssertionUtils

  def test_can_render_basic_generic_service
    actual = GenericServices.new.service(
        GenericService.new('fancyservice', 'sh -c echo cool story bro').
            node('node5').node('node7')).to_xml('')

    expected_substr =
        '<service command="sh -c echo cool story bro" name="fancyservice" version="1.0">
           <node hostalias="node5" />
           <node hostalias="node7" />
         </service>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_node1_provided_by_default_if_no_nodes_given
    actual = GenericServices.new.service(
        GenericService.new('coolservice', 'true')).to_xml('')

    expected_substr =
        '<service command="true" name="coolservice" version="1.0">
           <node hostalias="node1" />
         </service>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

end
