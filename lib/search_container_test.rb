# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'testcase'

class SearchContainerTest < TestCase
  alias_method :super_stop, :stop

  # Returns the modulename for this testcase superclass.
  # It is used by factory for categorizing tests.
  def modulename
    "container"
  end

  def can_share_configservers?
    true
  end

  def stop
    add_dirty_nodeproxies(vespa.nodeproxies)
    super_stop
  end
end
