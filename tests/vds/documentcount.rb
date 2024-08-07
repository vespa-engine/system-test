# Copyright Vespa.ai. All rights reserved.
require 'persistent_provider_test'

class DocumentCount < PersistentProviderTest

  def setup
    set_owner("vekterli")
    set_description("Verify correct reporting of number of stored documents in VDS")
  end

  def timeout_seconds
    1800
  end

  def test_docsstored
    deploy_app(default_app)
    start

    10.times { |n|
        vespa.document_api_v1.put(
                Document.new("music", "id:ns:music:n=100:1" + n.to_s))
    }

    assert_numdocs(10)

    # Put to node 1 only
    10.times { |n|
        vespa.document_api_v1.put(
                Document.new("music", "id:ns:music:n=100:2" + n.to_s))
    }

    assert_numdocs(20)
  end

  def test_docsstored_merging
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start

    # Put to both nodes
    10.times { |n|
        vespa.document_api_v1.put(
                Document.new("music", "id:ns:music:n=100:x" + n.to_s))
    }

    assert_numdocs(10)

    vespa.stop_content_node("storage", "0")
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')
    vespa.storage["storage"].distributor["0"].wait_until_synced
    vespa.storage["storage"].distributor["1"].wait_until_synced

    assert_numdocs(10)


    # Put to node 1 only
    10.times { |n|
        vespa.document_api_v1.put(
                Document.new("music", "id:ns:music:n=100:1" + n.to_s))
    }

    assert_numdocs(20)

    # Sync all distributors before taking down cluster, since otherwise
    # bucket rechecking will spin and never complete (since buckets aren't
    # rechecked in cluster state down)
    vespa.storage["storage"].distributor["0"].wait_until_synced
    vespa.storage["storage"].distributor["1"].wait_until_synced
    # Stop node 1 too
    vespa.stop_content_node("storage", "1")
    vespa.storage["storage"].wait_until_cluster_down
    vespa.storage["storage"].distributor["0"].wait_until_synced
    vespa.storage["storage"].distributor["1"].wait_until_synced

    # Start node 0
    vespa.start_content_node("storage", "0")
    vespa.storage["storage"].storage["0"].wait_for_current_node_state('u')
    vespa.storage["storage"].distributor["0"].wait_until_synced
    vespa.storage["storage"].distributor["1"].wait_until_synced

    assert_numdocs(10)

    # Put to node 0 only
    10.times { |n|
        vespa.document_api_v1.put(
                Document.new("music", "id:ns:music:n=100:0" + n.to_s))
    }

    assert_numdocs(20)


    # Start node 1
    vespa.start_content_node("storage", "1")
    vespa.storage["storage"].storage["1"].wait_for_current_node_state('u')
    vespa.storage["storage"].distributor["0"].wait_until_synced
    vespa.storage["storage"].distributor["1"].wait_until_synced

    assert_numdocs(30)
  end

  def get_numdocs
    n = 0
    vespa.storage["storage"].distributor.each { |d|
	n = n + d[1].get_numdoc_stored
    }

    return n
  end

  def assert_numdocs(numDocs)
    until get_numdocs == numDocs
      puts "Waiting for there to be " + numDocs.to_s + " docs in the system. There is currently " + get_numdocs.to_s + " docs."
      sleep 5
    end
    puts "Now there are " + numDocs.to_s + " documents stored according to distributor 0"
    assert_equal(numDocs, get_numdocs)
  end

  def teardown
    stop
  end
end

