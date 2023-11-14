# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_block_disk_two_nodes_base'

class FeedBlockDiskTwoNodesTest < FeedBlockDiskTwoNodesBase

  def initialize(*args)
    super(*args)
  end

  def setup(*args)
    super(*args)
  end

  def test_proton_feed_block_document_v1_api_two_nodes_disklimit
    set_description("Test resource based feed block (in proton) using document v1 api, disk resource limit, and node addition for recovery")
    return if has_active_sanitizers

    run_feed_block_document_v1_api_two_nodes_disklimit_test(false)
  end

  def test_distributor_feed_block_document_v1_api_two_nodes_disklimit
    set_description("Test resource based feed block (in distributor) using document v1 api, disk resource limit, and node addition for recovery")
    return if has_active_sanitizers

    @block_feed_in_distributor = true
    run_feed_block_document_v1_api_two_nodes_disklimit_test(false)
  end

end
