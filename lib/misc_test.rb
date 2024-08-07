# Copyright Vespa.ai. All rights reserved.
require 'testcase'

class MiscTest < TestCase

  # Returns the modulename for this testcase superclass.
  # It is used by factory for categorizing tests.
  def modulename
    "misc"
  end

  def can_share_configservers?
    true
  end

end
