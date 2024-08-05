# Copyright Vespa.ai. All rights reserved.
require 'disk_provider_storage_test'

class Migration < DiskProviderStorageTest

  def setup
    @valgrind=false
    set_owner("vekterli")
    deploy_app(default_app.
               num_nodes(4).
               redundancy(2).
               min_storage_up_ratio(0.2))
    start
  end

  def timeout_seconds
    1800
  end

  def test_migration
    vespa.stop_content_node("storage", "3")

    # Put some documents
    doc1 = Document.new("music", "id:crawler:music::http//yahoo.com/storage_test")
    vespa.document_api_v1.put(doc1)
    doc2 = Document.new("music", "id:crawler:music::http//google.com/storage_test")
    vespa.document_api_v1.put(doc2)
    doc3 = Document.new("music", "id:crawler:music::http//msn.com/storage_test")
    vespa.document_api_v1.put(doc3)

    # Check that the documents are stored two times
    statinfo1 = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//yahoo.com/storage_test")
    assert_equal(2, statinfo1.size)

    statinfo2 = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//google.com/storage_test")
    assert_equal(2, statinfo2.size)

    statinfo3 = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//msn.com/storage_test")
    assert_equal(2, statinfo3.size)

    # Stop a node
    vespa.stop_content_node("storage", "1")

    # Check that we can still fetch the docs
    ret = vespa.document_api_v1.get("id:crawler:music::http//yahoo.com/storage_test")
    assert_equal(doc1, ret)
    ret = vespa.document_api_v1.get("id:crawler:music::http//google.com/storage_test")
    assert_equal(doc2, ret)
    ret = vespa.document_api_v1.get("id:crawler:music::http//msn.com/storage_test")
    assert_equal(doc3, ret)

    # Wait until migration is done
    vespa.storage["storage"].wait_until_ready

    # Check that the documents are still stored two times
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//yahoo.com/storage_test")
    assert_equal(2, statinfo.size)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//google.com/storage_test")
    assert_equal(2, statinfo.size)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//msn.com/storage_test")
    assert_equal(2, statinfo.size)

    # Restart node
    vespa.start_content_node("storage", 1)
    vespa.storage["storage"].wait_until_ready

    # Check that documents are stored in the same places as before we stopped the node
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//yahoo.com/storage_test")
    assert_equal(statinfo1, statinfo)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//google.com/storage_test")
    assert_equal(statinfo2, statinfo)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//msn.com/storage_test")
    assert_equal(statinfo3, statinfo)

    # Take up fourth node
    vespa.start_content_node("storage", "3")

    # Wait for sync
    vespa.storage["storage"].wait_for_node_count("distributor", 4, "u")
    vespa.storage["storage"].wait_for_node_count("storage", 4, "u")
    vespa.storage["storage"].wait_until_ready

    # Check that the documents are still stored two times
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//yahoo.com/storage_test")
    assert_equal(2, statinfo.size)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//google.com/storage_test")
    assert_equal(2, statinfo.size)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//msn.com/storage_test")
    assert_equal(2, statinfo.size)

    # Stop fourth node
    vespa.stop_content_node("storage", "3")
    vespa.storage["storage"].wait_until_ready

    # Check that documents are stored in the same places as when we had only 3 nodes
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//yahoo.com/storage_test")
    assert_equal(statinfo1, statinfo)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//google.com/storage_test")
    assert_equal(statinfo2, statinfo)

    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//msn.com/storage_test")
    assert_equal(statinfo3, statinfo)
  end

  def teardown
    stop
  end
end

