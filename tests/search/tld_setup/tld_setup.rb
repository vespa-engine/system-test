# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class TldSetup < IndexedSearchTest
   
  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    set_owner("musum")
    set_description("Check that there is one tld per qrserver cluster per search cluster.")
  end

  def test_1_qcluster_1_qnode_1_scluster
    assert_tld_setup(1, 1, 1)
  end

  def test_1_qcluster_1_qnode_2_sclusters
    assert_tld_setup(1, 1, 2)
  end

  def test_1_qcluster_2_qnodes_1_scluster
    assert_tld_setup(1, 2, 1)
  end

  def test_1_qcluster_2_qnodes_2_sclusters
    assert_tld_setup(1, 2, 2)
  end

  def test_2_qclusters_1_qnode_1_scluster
    assert_tld_setup(2, 1, 1)
  end

  def test_2_qclusters_1_qnode_2_sclusters
    assert_tld_setup(2, 1, 2)
  end

  def test_2_qclusters_2_qnodes_1_scluster
    assert_tld_setup(2, 2, 1)
  end

  def test_2_qclusters_2_qnodes_2_sclusters
    assert_tld_setup(2, 2, 2)
  end

  def assert_tld_setup(num_qrserver_clusters, num_qrserver_nodes, num_search_clusters)
    deploy_custom_app(num_qrserver_clusters, num_qrserver_nodes, num_search_clusters)
    start

    # calculate number of expected tlds
    qrserver_node_cnt = num_qrserver_clusters * num_qrserver_nodes
    num_tlds = qrserver_node_cnt * num_search_clusters

    # verify services using framework model
    puts "Wait for #{num_qrserver_clusters} qrserver clusters.."
    wait_for { vespa.qrs.length == num_qrserver_clusters }
    for qrserver_cluster in vespa.qrs.keys
      puts "Wait for #{num_qrserver_nodes} nodes in qrserver cluster '#{qrserver_cluster}'.."
      wait_for { vespa.qrs[qrserver_cluster].qrserver.length == num_qrserver_nodes }
    end

    puts "Wait for #{num_search_clusters} search clusters.."
    wait_for { vespa.search.length == num_search_clusters }
    for search_cluster in vespa.search.keys 
      puts "Wait for #{qrserver_node_cnt} tlds in search cluster '#{search_cluster}'.."
      wait_for { vespa.search[search_cluster].topleveldispatch.length == qrserver_node_cnt }
    end

    # verify services using vespa-model-inspect
    out = vespa.adminserver.execute("vespa-model-inspect service topleveldispatch 2>/dev/null | grep FS4 | uniq");
    assert_equal(num_tlds, out.lines.count, "wrong number of dispatchers reported by vespa-model-inspect")

    # verify config given to ClusterSearch in qrserver clusters
    for search_cluster in vespa.search.keys 
      suffix = "/searchchains/chain/#{search_cluster}/component/com.yahoo.prelude.cluster.ClusterSearcher";
      for qrserver_cluster in vespa.qrs.keys
        assert_qrsearchers(num_tlds, "#{qrserver_cluster}#{suffix}")
     end
    end
  end

  def assert_qrsearchers(expected_num_tlds, config_id)
    out = vespa.adminserver.execute("vespa-get-config -n container.qr-searchers -i #{config_id} 2>/dev/null | grep searchcluster | grep dispatcher | grep port | uniq")
    assert_equal(expected_num_tlds, out.lines.count,
                 "wrong number of dispatchers in qr-searchers config for component '#{config_id}'")
  end

  def deploy_custom_app(num_qrserver_clusters, num_qrserver_nodes, num_search_clusters)
    app = SearchApp.new.num_hosts(2)
    (1..num_qrserver_clusters).each do |i|
      cluster = Container.new("my_qrserver_cluster#{i}").
                    search(Searching.new).
                    http(Http.new.
                         server(Server.new("default", 4080 + i*10)))
      (1..num_qrserver_nodes).each do |j|
        cluster.node({ :hostalias => "node#{j}" })
      end
      app.container(cluster)
    end
    (1..num_search_clusters).each do |i| 
      app.cluster(SearchCluster.new("my_search_cluster#{i}").sd("#{SEARCH_DATA}/music.sd"))
    end
    deploy_app(app);
  end

  def secs_remaining
    return get_timeout - (Time.now.to_i - @starttime.to_i)
  end

  def wait_for(&block)
    Timeout::timeout(secs_remaining) do
      while !block.call
        sleep 1
      end
    end
  end

  def teardown
    stop
  end

end
