# Copyright Vespa.ai. All rights reserved.
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
