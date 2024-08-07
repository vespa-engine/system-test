# Copyright Vespa.ai. All rights reserved.
require_relative 'feed_block_disk_two_nodes_base'

class FeedBlockSharedDiskTwoNodesTest < FeedBlockDiskTwoNodesBase

  def initialize(*args)
    super(*args)
  end

  def setup(*args)
    super(*args)
  end

  def test_proton_feed_block_shared_disk
    set_description("Test resource based feed block (in proton) using document v1 api, shared disk in proton, and node addition for recovery")
    run_feed_block_document_v1_api_two_nodes_disklimit_test(true)
  end

  def test_distributor_feed_block_shared_disk
    set_description("Test resource based feed block (in distributor) using document v1 api, shared disk in proton, and node addition for recovery")
    @block_feed_in_distributor = true
    @debug_log_enabled = true
    run_feed_block_document_v1_api_two_nodes_disklimit_test(true)
  end

end
