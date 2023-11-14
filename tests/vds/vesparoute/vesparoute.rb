# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/search_app'
require 'app_generator/storage_app'
require 'vds_test'
require 'environment'

class VespaRoute < VdsTest

  PATH = "#{Environment.instance.vespa_home}/tmp/vespa-route_" + Time.now.to_i.to_s

  def setup
    set_owner("vekterli")
  end

  def test_functionality
    set_expected_logged(/this search engine .* is Out Of Service/)
    deploy("#{selfdir}/setup_modular/")
    start

    # test hops
    assert(vespa.adminserver.execute("vespa-route --hops").
           include?("There are 3 hop(s):\n" +
                    "    1. backdoor\n" +
                    "    2. container/chain.indexing\n" +
                    "    3. indexing\n"))

    # test hop
    assert(vespa.adminserver.execute("vespa-route --hop indexing").
           include?("The hop 'indexing' has selector:\n" +
                    "       [DocumentRouteSelector]\n" +
                    "And 1 recipient(s):\n" +
                    "    1. search\n"))

    # test hop w. verify
    assert(vespa.adminserver.execute("vespa-route --hop container/chain.indexing --verify").
           include?("The hop 'container/chain.indexing' has selector:\n" +
                    "       [LoadBalancer:cluster=container;session=chain.indexing] (verified)\n"))

    # test routes
    assert(vespa.adminserver.execute("vespa-route --routes").
           include?("There are 7 route(s):\n" +
                    "    1. backdoor\n" +
                    "    2. default\n" +
                    "    3. default-get\n" +
                    "    4. search\n" +
                    "    5. search-direct\n" +
                    "    6. search-index\n" +
                    "    7. storage/cluster.search\n"))

    # test route
    assert(vespa.adminserver.execute("vespa-route --route search").
           include?("The route 'search' has 1 hop(s):\n" +
                    "    1. [MessageType:search]\n"))

    # test route w. verify
    assert(vespa.adminserver.execute("vespa-route --route search-index --verify").
           include?("The route 'search-index' has 2 hop(s):\n" +
                    "    1. container/chain.indexing (verified)\n" +
                    "    2. [Content:cluster=search] (verified)\n"))

    # test services
    assert(vespa.adminserver.execute("vespa-route --services").
           include?("There are 5 service(s):\n" +
                    "    1. container/container.0/chain.indexing\n" +
                    "    2. storage/cluster.search/distributor/0/default\n" +
                    "    3. storage/cluster.search/distributor/1/default\n" +
                    "    4. storage/cluster.search/storage/0/default\n" + 
                    "    5. storage/cluster.search/storage/1/default\n"))
  end

  def test_dumpError
    deploy("#{selfdir}/setup/")
    assertDump("<protocol name='document'>\n" +
               "    <hop name='backdoor' selector='[MessageType:search]'>\n" +
               "        <recipient session='search' />\n" +
               "    </hop>\n" +
               "    <hop name='container/chain.indexing' selector='[LoadBalancer:cluster=container;session=chain.indexing]' />\n" +
               "    <hop name='indexing' selector='[DocumentRouteSelector]'>\n" +
               "        <recipient session='search' />\n" +
               "    </hop>\n" +
               "    <route name='backdoor' hops='container/*/chain.music.indexing backdoor'>\n" +
               "        <error>for hop 'container/*/chain.music.indexing', no matching services</error>\n" +
               "    </route>\n" +
               "    <route name='default' hops='container/*/chain.blocklist indexing'>\n" +
               "        <error>for hop 'container/*/chain.blocklist', no matching services</error>\n" +
               "    </route>\n" +
               "    <route name='default-get' hops='[Content:cluster=search]' />\n" +
               "    <route name='search' hops='[MessageType:search]' />\n" +
               "    <route name='search-direct' hops='[Content:cluster=search]' />\n" +
               "    <route name='search-index' hops='container/chain.indexing [Content:cluster=search]' />\n" +
               "    <route name='storage/cluster.search' hops='route:search' />\n" +
               "</protocol>\n",
               [ "container/container.0/chain.indexing",
                  "storage/cluster.search/distributor/1/default",
                  "storage/cluster.search/distributor/0/default",
                  "storage/cluster.search/storage/1/default",
                  "storage/cluster.search/storage/0/default"])
  end

  def music_sd
    "#{selfdir}/setup/schemas/music.sd"
  end

  def test_dumpSinglenode
    app = SearchApp.new.sd(music_sd).qrserver(QrserverCluster.new)
    deploy_app(app)
    assertDump("<protocol name='document'>\n" +
               "    <hop name='default/chain.indexing' selector='[LoadBalancer:cluster=default;session=chain.indexing]' />\n" +
               "    <hop name='indexing' selector='[DocumentRouteSelector]'>\n" +
               "        <recipient session='search' />\n" +
               "    </hop>\n" +
               "    <route name='default' hops='indexing' />\n" +
               "    <route name='default-get' hops='[Content:cluster=search]' />\n" +
               "    <route name='search' hops='[MessageType:search]' />\n" +
               "    <route name='search-direct' hops='[Content:cluster=search]' />\n" +
               "    <route name='search-index' hops='default/chain.indexing [Content:cluster=search]' />\n" +
               "    <route name='storage/cluster.search' hops='route:search' />\n" +
               "</protocol>\n",
               [ "default/container.0/chain.indexing",
                 "storage/cluster.search/distributor/0/default",
                 "storage/cluster.search/storage/0/default"])
  end

  def test_dumpSinglenodeStreaming
    app = SearchApp.new.streaming.sd(music_sd).qrserver(QrserverCluster.new)
    deploy_app(app)
    assertDump("<protocol name='document'>\n" +
               "    <hop name='indexing' selector='[DocumentRouteSelector]'>\n" +
               "        <recipient session='search' />\n" +
               "    </hop>\n" +
               "    <route name='default' hops='indexing' />\n" +
               "    <route name='default-get' hops='[Content:cluster=search]' />\n" +
               "    <route name='search' hops='[Content:cluster=search]' />\n" +
               "    <route name='storage/cluster.search' hops='route:search' />\n" +
               "</protocol>\n",
               [ "storage/cluster.search/distributor/0/default",
                 "storage/cluster.search/storage/0/default" ])
  end

  def test_dumpStorage1x1
    app = StorageApp.new.default_cluster.streaming.sd(music_sd).qrserver(QrserverCluster.new)
    deploy_app(app)

    assertDump("<protocol name='document'>\n" +
               "    <hop name='indexing' selector='[DocumentRouteSelector]'>\n" +
               "        <recipient session='storage' />\n" +
               "    </hop>\n" +
               "    <route name='default' hops='indexing' />\n" +
               "    <route name='default-get' hops='[Content:cluster=storage]' />\n" +
               "    <route name='storage' hops='[Content:cluster=storage]' />\n" +
               "    <route name='storage/cluster.storage' hops='route:storage' />\n" +
               "</protocol>",
               [ "storage/cluster.storage/storage/0/default",
                 "storage/cluster.storage/distributor/0/default" ])
  end

  def test_dumpStorageClusterName
    app = StorageApp.new.default_cluster("nonstandard").streaming.sd(music_sd).qrserver(QrserverCluster.new)
    deploy_app(app)

    assertDump("<protocol name='document'>\n" +
               "    <hop name='indexing' selector='[DocumentRouteSelector]'>\n" +
               "        <recipient session='nonstandard' />\n" +
               "    </hop>\n" +
               "    <route name='default' hops='indexing' />\n" +
               "    <route name='default-get' hops='[Content:cluster=nonstandard]' />\n" +
               "    <route name='nonstandard' hops='[Content:cluster=nonstandard]' />\n" +
               "    <route name='storage/cluster.nonstandard' hops='route:nonstandard' />\n" +
               "</protocol>",
               [ "storage/cluster.nonstandard/distributor/0/default",
                 "storage/cluster.nonstandard/storage/0/default" ])
  end

  def test_dumpStorage2x2
    app = StorageApp.new.default_cluster.num_nodes(2).sd(music_sd).qrserver(QrserverCluster.new)
    deploy_app(app)

    assertDump("<protocol name='document'>\n" +
               "    <hop name='indexing' selector='[DocumentRouteSelector]'>\n" +
               "        <recipient session='storage' />\n" +
               "    </hop>\n" +
               "    <route name='default' hops='indexing' />\n" +
               "    <route name='default-get' hops='[Content:cluster=storage]' />\n" +
               "    <route name='storage' hops='[Content:cluster=storage]' />\n" +
               "    <route name='storage/cluster.storage' hops='route:storage' />\n" +
               "</protocol>",
               [ "storage/cluster.storage/distributor/0/default",
                 "storage/cluster.storage/distributor/1/default",
                 "storage/cluster.storage/storage/0/default",
                 "storage/cluster.storage/storage/1/default" ])
  end

  def assertDump(protocol, services)
    start
    dump = vespa.adminserver.execute("vespa-route --dump")
    assert(dump.include?(protocol))
    services.each { |service|
      assert(dump.include?("<service name='#{service}'"))
    }
  end

  def teardown
    stop
  end

end
