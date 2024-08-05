# Copyright Vespa.ai. All rights reserved.
require 'test/unit'

module AssertionUtils

  def assert_substring_ignore_whitespace(actual, expected_substr)
    assert(actual.split(/[\s]+/).join(' ').
               include?(expected_substr.split(/[\s]+/).join(' ')),
           "Expected '#{expected_substr}' to be a substring of '#{actual}'")
  end

end

