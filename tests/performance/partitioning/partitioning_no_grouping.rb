# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/partitioning/partitioning'

class SearchPartitioningNoGrouping < SearchPartitioningBase

  def test_thread_scaling_no_grouping
    set_owner("havardpe")
    @queryfile = selfdir + 'queries.txt'
    thread_scaling_test
  end

end
