# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class ChangeCopies < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(2).redundancy(1))
    start
  end

  def test_change_copies
    docA = Document.new("music", "id:crawler:music::http://yahoo.com/A")
    vespa.document_api_v1.put(docA)

    # Check that document is on one node
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http://yahoo.com/A", include_owner: false)
    assert_equal(1, statinfo.size)

    deploy_app(default_app.num_nodes(2).redundancy(2).validation_override("redundancy-increase"))
    sleep 5
    vespa.storage["storage"].wait_until_ready

    # Check that document is on both nodes
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http://yahoo.com/A", include_owner: false)
    assert(statinfo.has_key?("0"))
    assert(statinfo.has_key?("1"))
    assert_equal(statinfo["0"], statinfo["1"])

    deploy_app(default_app.num_nodes(2).redundancy(1))
    sleep 5
    vespa.storage["storage"].wait_until_ready

    # Check that document is on one node
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http://yahoo.com/A", include_owner: false)
    assert_equal(1, statinfo.size)
  end

  def teardown
    stop
  end

end

