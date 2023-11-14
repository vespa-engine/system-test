# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/partitioning/partitioning'

class SearchPartitioningGrouping < SearchPartitioningBase

  def test_thread_scaling_grouping
    set_owner("havardpe")
    @queryfile = selfdir + 'queries_grouping.txt'
    thread_scaling_test
  end

end
