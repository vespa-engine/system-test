# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'testcase'

# A test case which runs against the hosted system rather than a locally installed vespa
class HostedTest < TestCase

  # Returns the modulename for this testcase superclass.
  # It is used by factory for categorizing tests.
  def modulename
    "hosted"
  end

end
