# Copyright Vespa.ai. All rights reserved.

require 'performance/partitioning/partitioning'

class SearchPartitioningGrouping < SearchPartitioningBase

  def test_thread_scaling_grouping
    set_owner("havardpe")
    @queryfile = selfdir + 'queries_grouping.txt'
    thread_scaling_test
  end

end
