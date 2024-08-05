# Copyright Vespa.ai. All rights reserved.

require 'performance/partitioning/partitioning'

class SearchPartitioningNoGrouping < SearchPartitioningBase

  def test_thread_scaling_no_grouping
    set_owner("havardpe")
    @queryfile = selfdir + 'queries.txt'
    thread_scaling_test
  end

end
