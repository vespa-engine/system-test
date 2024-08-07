# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class ClientLoadDuringOrchestratedDownTest < VdsTest

  def setup
    set_owner('vekterli')
  end

  def teardown
    stop
  end

  def make_doc_id(n)
    "id:test:music::doc#{n}"
  end

  def feed_doc(id)
    doc = Document.new('music', id)
    vespa.document_api_v1.put(doc)
  end

  def feed_n_docs(n)
    n.times{|i| feed_doc(make_doc_id(i)) }
  end

  def content_cluster
    vespa.storage['storage']
  end

  def test_clients_not_stalled_by_orchestrated_down_distributor
    set_description('Test that client load towards a distributor that has been explicitly ' +
                    'marked Down in the cluster state does not cause clients to hang')

    deploy_app(default_app.num_nodes(2).redundancy(2))
    start

    # Feed enough docs that it's effectively guaranteed that the client has touched
    # more than a single distributor correctly by chance, and therefore has received
    # and cached a cluster state
    feed_n_docs(16)

    stat = content_cluster.distributor['0'].stat(make_doc_id(0))
    target = stat.select {|k,v| v['owner'] == true }.map{|k,v| k}.first
    assert_not_nil target

    puts "Explicitly marking distributor #{target} Down in cluster state"
    content_cluster.get_master_cluster_controller.set_node_state('storage', 'distributor', target, 's:d')
    # set_node_state ensures state visibility by default, so at this point the state change shall have taken effect.
 
    # Since send failures will eventually cause the StoragePolicy to wipe its state and send to a random
    # distributor, we send off several Gets until we hit a case where the coin flip lands on the aborting
    # node several times in a row.
    16.times {|n| 
      id = make_doc_id(0)
      doc = vespa.document_api_v1.get(id)
      assert_not_nil doc
      assert_equal(id, doc.documentid)
    }
    puts 'All client operations succeeded; no client stall triggered'
  end

end

