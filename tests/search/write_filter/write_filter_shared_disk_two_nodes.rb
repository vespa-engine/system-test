# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search/write_filter/write_filter_disk_two_nodes_base'

class WriterFilterSharedDiskTwoNodes < WriterFilterDiskTwoNodesBase

  def initialize(*args)
    super(*args)
  end

  def setup(*args)
    super(*args)
  end

  def test_write_filter_shared_disk
    set_description("Test resource based write filter using document v1 api, shared disk in proton, and node addition for recovery")
    run_write_filter_document_v1_api_two_nodes_disklimit_test(true)
  end

end
