# Copyright Vespa.ai. All rights reserved.

# -*- coding: utf-8 -*-
require 'indexed_only_search_test'
require 'document'
require 'simple_http_feeder'


class Down < IndexedOnlySearchTest

  def setup
    set_owner("toregge")
    set_description("Verify that documents are searchable after put")
    @doc_type = "down"
    @id_prefix = "id:test:#{@doc_type}::"
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @feeder = nil
    @nodestate_cli_app = "vespa-set-node-state";
  end

  def get_base_sc(parts, r, rc)
    SearchCluster.new("down").
      sd(selfdir + "down.sd").
      num_parts(parts).
      redundancy(r).
      indexing("default").
      ready_copies(rc)
  end

  def create_groups(pergroup)
    NodeGroup.new(0, "mytopgroup").
      distribution("#{pergroup}|#{pergroup}|*").
      group(NodeGroup.new(0, "mygroup0").
            node(NodeSpec.new("node1", 0)).
            node(NodeSpec.new("node1", 1)).
            node(NodeSpec.new("node1", 2))).
      group(NodeGroup.new(1, "mygroup1").
            node(NodeSpec.new("node1", 3)).
            node(NodeSpec.new("node1", 4)).
            node(NodeSpec.new("node1", 5))).
      group(NodeGroup.new(2, "mygroup2").
            node(NodeSpec.new("node1", 6)).
            node(NodeSpec.new("node1", 7)).
            node(NodeSpec.new("node1", 8)))
  end

  def get_base_app(sc)
    SearchApp.new.cluster(sc)
  end

  def get_app(sc)
    get_base_app(sc)
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def document_api_v1
    vespa.document_api_v1
  end

  def get_cluster
    vespa.storage["down"]
  end

  def get_clustercontroller
    get_cluster.get_master_fleet_controller
  end

  def set_node_state(state)
    get_clustercontroller.set_node_state("storage", 0, state)
  end

  def wait_node_state(state)
    get_cluster.wait_for_current_node_state("storage", 0, state)
  end

  def get_cluster_state
    get_cluster.get_cluster_state
  end

  def settle_cluster_state(check_states = "ui") 
    get_clustercontroller.wait_for_matching_distribution_states
    clusterstate = get_cluster_state
    get_cluster.wait_for_cluster_state_propagate(clusterstate, 300,
                                                 check_states)
  end

  def settle_cluster_state_allnodes
    settle_cluster_state("uimrd")
  end

  def set_node_down(cli = false)
    if cli
      vespa.adminserver.
        execute("#{@nodestate_cli_app} --type storage --index 0 " +
                "--config-request-timeout 60 " \
                "down downtestdown")
    else
      set_node_state("s:d")
    end
    wait_node_state('d')
    settle_cluster_state_allnodes
  end

  def set_node_up(cli = false)
    if cli
      vespa.adminserver.
        execute("#{@nodestate_cli_app} --type storage --index 0 " +
                "--config-request-timeout 60 " \
                "up downtestup")
    else
      set_node_state("s:u")
    end
    wait_node_state('u')
    settle_cluster_state_allnodes
    # Status page in vespa-fdispatch has been removed, cannot use it to poll for
    # node being seen as up.  Just sleep 3 seconds, and increase sleep if
    # failure rate is too high.
    sleep 3
  end

  def hcs
    "/search/?query=sddocname:down&nocache&hits=0&ranking=unranked"
  end

  def feed_range(count, lower = 0)
    for i in lower..lower+count-1
      @feeder.assert_doccount(i, 0)
    end
    for i in lower..lower+count-1
      puts "Feeding doc #{i}"
      @feeder.gen_and_put_doc(i)
    end
    for i in lower..lower+count-1
      @feeder.wait_doccount(i, 1)
    end
  end
    

  def create_feeder
    @feeder = SimpleHTTPFeeder.new(self, 
                                   qrserver, document_api_v1,
                                   @doc_type, @id_prefix, "i1")
  end

  def enable_proton_debug_log
    vespa.search["down"].searchnode.each_value do |proton|
      proton.logctl2("proton.server.storeonlyfeedview", "all=on")
      proton.logctl2("proton.persistenceengine.persistenceengine", "all=on")
      proton.logctl2("proton.server.buckethandler", "all=on")
      proton.logctl2("persistence.thread", "debug=on")
    end
    qrserver.logctl2("com.yahoo.jdisc.http.server.dispatch.HttpRequestDispatch", "all=on")
    qrserver.logctl("container:com.yahoo.jdisc.http.server.dispatch.HttpRequestDispatch", "all=on")
  end

  def test_single_node_single_doc_down
    sc = get_base_sc(1, 1, 1)
    app = get_app(sc)
    deploy_app(app)
    start
    enable_proton_debug_log
    create_feeder
    @feeder.assert_doccount(0, 0)
    @feeder.gen_and_put_doc(0)
    @feeder.assert_doccount(0, 1)
    set_node_down
    @feeder.assert_doccount(0, 0)
    set_node_up
    @feeder.assert_doccount(0, 1)
  end

  def perform_test_single_node_down(cli)
    sc = get_base_sc(1, 1, 1)
    app = get_app(sc)
    deploy_app(app)
    start
    enable_proton_debug_log
    create_feeder
    cnt = 100
    feed_range(cnt)
    assert_hitcount(hcs, cnt)
    set_node_down(cli)
    @feeder.assert_doccount(0, 0)
    assert_hitcount(hcs, 0)
    set_node_up(cli)
    @feeder.assert_doccount(0, 1)
    assert_hitcount(hcs, cnt)
  end

  def test_single_node_down
    perform_test_single_node_down(false)
  end

  def test_single_node_down_cli
    perform_test_single_node_down(true)
  end

  def test_four_nodes_single_down_no_redundancy
    sc = get_base_sc(4, 1, 1)
    app = get_app(sc)
    deploy_app(app)
    start
    create_feeder
    cnt = 100
    feed_range(cnt)
    assert_hitcount(hcs, cnt)
    hc0 = search(hcs + "&searchpath=0/0").hitcount
    puts "hitcount on node 0 is #{hc0}"
    set_node_down
    hc = search(hcs).hitcount
    puts "hitcount with remaining 3 of 4 nodes is #{hc}"
    assert_equal(cnt - hc0, hc, "Unexpected number of degraded hits")
    set_node_up
    assert_hitcount(hcs, cnt)
  end

  def test_four_nodes_single_down_redundancy
    sc = get_base_sc(4, 2, 2)
    app = get_app(sc)
    deploy_app(app)
    start
    enable_proton_debug_log
    create_feeder
    cnt = 100
    feed_range(cnt)
    assert_hitcount(hcs, cnt)
    hc0 = search(hcs + "&searchpath=0/0").hitcount
    puts "hitcount on node 0 is #{hc0}"
    set_node_down
    while true
      hc = search(hcs).hitcount
      puts "hitcount on remaining 3 of 4 nodes is #{hc}"
      break if hc == cnt
      sleep 0.1
    end
    set_node_up
    while true
      hc = search(hcs).hitcount
      puts "hitcount on all 4 nodes is #{hc}"
      break if hc == cnt
      sleep 0.1
    end
  end

  def perform_test_nine_nodes_hierarchic_distribution_single_down(lr)
    sc = get_base_sc(9, lr * 3, lr * 3).group(create_groups(lr))
    app = get_app(sc)
    deploy_app(app)
    start
    enable_proton_debug_log
    create_feeder
    cnt = 100
    feed_range(cnt)
    assert_hitcount(hcs, cnt)
    hc0 = search(hcs + "&searchpath=0/0").hitcount
    puts "hitcount on node 0 is #{hc0}"
    set_node_down(true)
    10.times do
      hc = search(hcs).hitcount
      puts "hitcount with remaining 8 of 9 nodes before sleep is #{hc}"
      if lr == 1
        assert_equal(true, cnt - hc0 == hc || cnt == hc,
                     "Unexpected number of degraded hits before sleep")
      else
        assert(hc >= cnt - hc0 && hc <= cnt,
               "Unexpected number of degraded hits before sleep")
      end
    end
    # give vespa-fdispatch time to take mygroup0 out of rotation
    sleep 5
    10.times do
      hc = search(hcs).hitcount
      puts "hitcount with remaining 8 of 9 nodes after sleep is #{hc}"
      assert_equal(cnt, hc, "Unexpected number of degraded hits after sleep")
    end
    set_node_up(true)
    sleep 5
    10.times do
      hc = search(hcs).hitcount
      puts "hitcount with remaining 8 of 9 nodes after reup is #{hc}"
      if lr == 1
        assert_equal(cnt, hc, "Unexpected number of degraded hits after reup")
      else
        assert(hc >= cnt - hc0 && hc <= cnt + hc0,
               "Unexpected number of degraded hits after reup")
      end
    end
    assert_hitcount(hcs, cnt)
  end

  def test_nine_nodes_hierarchic_distribution_single_down_no_redundancy
    @valgrind = false
    perform_test_nine_nodes_hierarchic_distribution_single_down(1)
  end

  def test_nine_nodes_hierarchic_distribution_single_down_redundancy
    @valgrind = false
    perform_test_nine_nodes_hierarchic_distribution_single_down(2)
  end

  def teardown
    stop
  end

end
