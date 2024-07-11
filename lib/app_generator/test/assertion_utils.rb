# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'

module AssertionUtils

  def assert_substring_ignore_whitespace(actual, expected_substr)
    assert(actual.split(/[\s]+/).join(' ').
               include?(expected_substr.split(/[\s]+/).join(' ')),
           "Expected '#{expected_substr}' to be a substring of '#{actual}'")
  end

end

