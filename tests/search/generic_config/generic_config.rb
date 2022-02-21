# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class GenericConfig < IndexedSearchTest

  def can_share_configservers?(method_name=nil)
    false
  end

  def get_app
    SearchApp.new.
        admin(Admin.new.config(ConfigOverride.new("cloud.config.log.logd").add("rotate", ConfigValues.new.add("age", "1234")))).
        container(Container.new.
                node(:config => ConfigOverride.new("search.config.qr-start").
                    add("jvm", ConfigValue.new("directMemorySizeCache", 20))).
                config(ConfigOverride.new("com.yahoo.vespatest.extra-hit").
                           add("exampleString", "Heal the World!").
                           add(ArrayConfig.new("regions").
                                   add(0, ConfigValue.new("language", "any")).
                                   add(0, ArrayConfig.new("value").
                                   add(0, "us")))).
                config(ConfigOverride.new("container.qr-searchers").
                       add("tag", ConfigValues.new.
                           add("bold",
                               ConfigValues.new.
                               add("open", "&lt;em&gt;").
                               add("close", "&lt;/em&gt;")).
                           add("separator", "&lt;p&gt;"))).
                search(Searching.new.
                         chain(Searcher.new("com.yahoo.vespatest.ExtraHitSearcher")).
                         chain(Searcher.new("AnotherExtraHitSearcher").
                                      klass("com.yahoo.vespatest.ExtraHitSearcher").
                                      config(ConfigOverride.new("com.yahoo.vespatest.extra-hit").
                                             add("exampleString", "You Rock my World").
                                             add(ArrayConfig.new("score").
                                                 add(0, ConfigValue.new("language", "english")).
                                                 add(0, ConfigValue.new("value", "3.1"))))).
                         chain(Chain.new.inherits(nil).
                                      config(ConfigOverride.new("com.yahoo.vespatest.extra-hit").
                                             add("exampleString", "We Are Here to Change the World").
                                             add(ArrayConfig.new("score").
                                                 add(0, ConfigValue.new("language", "french")).
                                                 add(0, ConfigValue.new("value", "5.5")))).
                                      add(Searcher.new("com.yahoo.vespatest.ExtraHitSearcher")).
                                      add(Searcher.new("AnotherExtraHitSearcher")).
                                      add(Searcher.new("InnerExtraHitSearcher").
                                          klass("com.yahoo.vespatest.ExtraHitSearcher"))))).

      cluster(SearchCluster.new.sd(selfdir+"foo.sd").
              config(ConfigOverride.new("vespa.config.search.summary.juniperrc").
                     add("length", 1024).
                     add("max_matches", 5).
                     add("prefix", false).
                     add(ArrayConfig.new("override").
                         add(0, ConfigValue.new("fieldname", "artist")).
                         add(0, ConfigValue.new("length", 512)).
                         add(0, ConfigValue.new("max_matches", 1)).
                         add(0, ConfigValue.new("prefix", false)))).
              config(ConfigOverride.new("vespa.config.search.core.proton").
                      add("numsummarythreads", 32)).
              group(NodeGroup.new(0, "row0").
                    node(NodeSpec.new("node1", 0).
                         config(ConfigOverride.new("vespa.config.search.core.proton").
                                add("numsummarythreads", 34).
                                add("flush", ConfigValue.new("idleinterval", 700)))).
                    node(NodeSpec.new("node1", 1)))).
      storage(StorageCluster.new.
              sd(selfdir+"foo.sd").
              config(ConfigOverride.new("vespa.config.content.core.stor-integritychecker").
                     add("requestdelay", 2).
                     add("mincycletime", 1000)).
              default_group).

      config(ConfigOverride.new("vespa.config.content.core.stor-integritychecker").
               add("requestdelay", 3).
               add("maxpending", 3))
  end

  def setup
    set_owner("gjoranv")
    set_description("Tests that generic config overriding in services.xml works.")

    @getconfig = "vespa-get-config -w 10 -t 8"

    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.ExtraHitSearcher")
    deploy_app(get_app)
    start
  end

  def show_config_ids
    puts "Known configIds (not including search-chains):"
    vespa.adminserver.execute("vespa-model-inspect configids")
  end

  def test_generic_config
    scprefix = "search/search"
    dotest_qrs_config()
    dotest_searchchains_config()
    dotest_juniperrc(scprefix)
    dotest_searchcluster_config(scprefix)
    dotest_admin_config()
    #show_config_ids
    dotest_stor_integritychecker
  end

  def dotest_searchcluster_config(prefix)
    id = prefix + "/cluster.search"
    assert(vespa.adminserver.execute("#{@getconfig} -n vespa.config.search.core.proton -i #{id}/0") =~ /numsummarythreads 34/)
    assert(vespa.adminserver.execute("#{@getconfig} -n vespa.config.search.core.proton -i #{id}/1") =~ /numsummarythreads 32/)
    assert(vespa.adminserver.execute("#{@getconfig} -n vespa.config.search.core.proton -i #{id}/0") =~ /flush.idleinterval 700/)
    assert(vespa.adminserver.execute("#{@getconfig} -n vespa.config.search.core.proton -i #{id}/1") !~ /flush.idleinterval 700/)
  end

  def dotest_qrs_config()
    # qrserver.0
    qrsId = "default/container.0"
    assert(vespa.adminserver.execute("#{@getconfig} -n search.config.qr-start -i #{qrsId}") =~ /jvm.directMemorySizeCache 20/)
    qrSearchers = vespa.adminserver.execute("#{@getconfig} -n container.qr-searchers -i #{qrsId}")
    assert(qrSearchers =~ /tag.bold.open \"<em>\"/)
    assert(qrSearchers =~ /tag.bold.close \"<\/em>\"/)
    assert(qrSearchers =~ /tag.separator \"<p>\"/)
  end

  def dotest_searchchains_config()
    searcherId = "default/searchchains/component/com.yahoo.vespatest.ExtraHitSearcher"
    extraHit = vespa.adminserver.execute("#{@getconfig} -n com.yahoo.vespatest.extra-hit -i #{searcherId}")
    assert(extraHit =~ /Heal the World!/)
    assert(extraHit =~ /regions\[0\].language "any"/)
    assert(extraHit =~ /regions\[0\].value\[0\] "us"/)

    searcherId = "default/searchchains/component/AnotherExtraHitSearcher"
    extraHit = vespa.adminserver.execute("#{@getconfig} -n com.yahoo.vespatest.extra-hit -i #{searcherId}")
    assert(extraHit =~ /You Rock my World/)
    assert(extraHit =~ /score\[0\].language "english"/)
    assert(extraHit =~ /score\[0\].value \"3.1\"/)

    # Verify that config set under 'searchchain' reaches searchers that are declared within the chain (inner searcher)
    searcherId = "default/searchchains/chain/default/component/InnerExtraHitSearcher"
    extraHit = vespa.adminserver.execute("#{@getconfig} -n com.yahoo.vespatest.extra-hit -i #{searcherId}")
    assert(extraHit =~ /We Are Here to Change the World/)
    assert(extraHit =~ /score\[0\].language "french"/)
    assert(extraHit =~ /score\[0\].value \"5.5\"/)
  end

  def dotest_juniperrc(prefix)
    suffix = "foo"
    nodeId = prefix + "/cluster.search/" + suffix
    puts "nodeId = " + nodeId
    juniper = vespa.adminserver.execute("#{@getconfig} -n vespa.config.search.summary.juniperrc -i #{nodeId}")
    puts "juniper = " + juniper
    assert(juniper =~ /length 1024/)
    assert(juniper =~ /max_matches 5/)
    assert(juniper =~ /prefix false/)
    assert(juniper =~ /override\[0\].fieldname \"artist\"/)
    assert(juniper =~ /override\[0\].length 512/)
    assert(juniper =~ /override\[0\].max_matches 1/)
    assert(juniper =~ /override\[0\].prefix false/)
  end

  def dotest_stor_integritychecker
    storageId = "search" 
    storIntegrity = vespa.adminserver.execute("#{@getconfig} -n vespa.config.content.core.stor-integritychecker -i #{storageId}")
    assert(storIntegrity =~ /requestdelay 3/)
    assert(storIntegrity =~ /maxpending 3/)

    clusterId = "storage/storage"
    storIntegrity = vespa.adminserver.execute("#{@getconfig} -n vespa.config.content.core.stor-integritychecker -i #{clusterId}")
    assert(storIntegrity =~ /requestdelay 2/)
    assert(storIntegrity =~ /mincycletime 1000/)

    nodeId = "storage/storage/0"
    storIntegrity = vespa.adminserver.execute("#{@getconfig} -n vespa.config.content.core.stor-integritychecker -i #{nodeId}")
    assert(storIntegrity =~ /requestdelay 2/)
    assert(storIntegrity =~ /mincycletime 1000/)
  end

  def dotest_admin_config()
    admin_id = "admin"
    assert(vespa.adminserver.execute("#{@getconfig} -n cloud.config.log.logd -i #{admin_id}") =~ /rotate.age 1234/)
  end

  def teardown
    stop
  end

end
