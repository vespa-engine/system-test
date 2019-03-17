# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search/write_filter/write_filter_disk_two_nodes_base'

class WriterFilterDiskTwoNodes < WriterFilterDiskTwoNodesBase

  def initialize(*args)
    super(*args)
  end

  def setup(*args)
    super(*args)
  end

  def test_write_filter_document_v1_api_two_nodes_disklimit
    set_description("Test resource based write filter using document v1 api, disk resource limit, and node addition for recovery")
    run_write_filter_document_v1_api_two_nodes_disklimit_test(false)
  end

end
