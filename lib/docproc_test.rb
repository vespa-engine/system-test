# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'testcase'

class DocprocTest < TestCase

  # Returns the modulename for this testcase superclass.
  # It is used by factory for categorizing tests.
  def modulename
    "docproc"
  end

  # Returns the name of the feeder binary to be used.
  def feeder_binary
    "vespa-feeder"
  end

  def can_share_configservers?(method_name=nil)
    true
  end

end
