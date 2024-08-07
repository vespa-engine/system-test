# Copyright Vespa.ai. All rights reserved.

require 'persistent_provider_test'

class Redundancy < PersistentProviderTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
  end

  def timeout_seconds
    1800
  end

  def test_nice_redundancy
    docA = Document.new("music", "id:crawler:music::http://yahoo.com/A")
    vespa.document_api_v1.put(docA)

    docB = Document.new("music", "id:crawler:music::http://yahoo.com/B")
    vespa.document_api_v1.put(docB)

    # Remove storage node from system
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 0, "s:d")
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].wait_until_ready

    # Put and remove some docs
    docC = Document.new("music", "id:crawler:music::http://yahoo.com/C")
    vespa.document_api_v1.put(docC)

    vespa.document_api_v1.remove("id:crawler:music::http://yahoo.com/B")

    # Check that we can fetch doc
    doc = vespa.document_api_v1.get("id:crawler:music::http://yahoo.com/A")
    assert_equal(docA, doc)

    # Fetch removed doc
    doc = vespa.document_api_v1.get("id:crawler:music::http://yahoo.com/B")
    assert_equal(nil, doc)

    # Readd node
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 0, "s:u")

    # Check that we can fetch doc while syncing is going on
    for i in 1..30
      doc = vespa.document_api_v1.get("id:crawler:music::http://yahoo.com/C")
      assert_equal(docC, doc)
      sleep 0.1
    end

    # Make sure sync is done
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('u')
    vespa.storage["storage"].wait_until_ready

    # Check that document C is on both nodes
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http://yahoo.com/C", include_owner: false)
    assert(statinfo.has_key?("0"))
    assert(statinfo.has_key?("1"))
    assert_equal(statinfo["0"], statinfo["1"])

    # Check that document B is on neither node
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http://yahoo.com/B", include_owner: false)
    assert(0, statinfo.size)
  end

  def test_kill_node
    docA = Document.new("music", "id:crawler:music::http://yahoo.com/A")
    vespa.document_api_v1.put(docA)

    docB = Document.new("music", "id:crawler:music::http://yahoo.com/B")
    vespa.document_api_v1.put(docB)

    # Remove storage node from system
    vespa.stop_content_node("storage", "1")

    # Check that we can fetch doc
    doc = vespa.document_api_v1.get("id:crawler:music::http://yahoo.com/A")
    assert_equal(docA, doc)

    # Put and remove some docs.
    docC = Document.new("music", "id:crawler:music::http://yahoo.com/C")
    begin
      vespa.document_api_v1.put(docC)
    rescue
      sleep 1
      retry
    end

    begin
      vespa.document_api_v1.remove("id:crawler:music::http://yahoo.com/B")
    rescue
      sleep 1
      retry
    end

    # Fetch removed doc
    doc = vespa.document_api_v1.get("id:crawler:music::http://yahoo.com/B")
    assert_equal(nil, doc)

    # Readd node
    vespa.start_content_node("storage", "1")

    # Check that we can fetch doc while syncing is going on
    for i in 1..30
      doc = vespa.document_api_v1.get("id:crawler:music::http://yahoo.com/C")
      assert_equal(docC, doc)
      sleep 0.5
    end

    # Make sure sync is done
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('u')
    vespa.storage["storage"].wait_until_ready

    # Check that document C is on both nodes
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http://yahoo.com/C", include_owner: false)
    assert(statinfo.has_key?("0"))
    assert(statinfo.has_key?("1"))

    # Check that document B is on neither node
    statinfo = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http://yahoo.com/B", include_owner: false)
    assert(0, statinfo.size)
  end

  def teardown
    stop
  end

end

