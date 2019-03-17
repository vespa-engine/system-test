# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'docproc_test'
require 'search_test'
require 'app_generator/http'

class JvmTuning < SearchTest

  def can_share_configservers?(method_name=nil)
    false
  end

  def setup
    set_owner("musum")
    set_description("Test setting jvmargs in services.xml or with yinst settings")
  end

  def deploy_jvmtuning
    deploy_app(SearchApp.new.sd(selfdir+"foo.sd").
               logserver("node1", "-verbose:gc").
               container(Container.new.jvmgcoptions("-XX:+UseG1GC -XX:MaxTenuringThreshold=10").
                         jvmargs('-Dfoo=bar -Dvespa_foo="foo og bar" -Xms256m -Xms256m ' +
                                 '-XX:+PrintCommandLineFlags')).
               container(Container.new("docproc1").jvmargs("-XX:MaxTenuringThreshold=13 -XX:+PrintCommandLineFlags -Xms256m -Xms256m").
                         docproc(DocumentProcessing.new.chain(Chain.new("docproc1-chain").add(DocProc.new("com.yahoo.vespatest.WorstMusicDocProc")))).
                         http(Http.new.server(Server.new("server1", 5000)))))
  end

  def test_jvmtuning
    deploy_jvmtuning

    override_environment_setting(vespa.configservers["0"], "cloudconfig_server.jvmargs", "-verbose:gc -verbose:jni")
    override_environment_setting(vespa.adminserver, "services.jvmargs_configproxy", "-verbose:jni -verbose:gc")
    override_environment_setting(vespa.adminserver, "vespa_metrics_proxy.jvmargs", "-verbose:jni -verbose:gc")
    vespa.configservers["0"].stop_configserver
    vespa.configservers["0"].start_configserver
    add_bundle(DOCPROC+"/WorstMusicDocProc.java")
    deploy_jvmtuning
    start

    assert(vespa.adminserver.execute("ps auxwww | grep configserver") =~ /-verbose:gc -verbose:jni/)
    assert(vespa.adminserver.execute("ps auxwww | grep configproxy") =~ /-verbose:jni -verbose:gc/)
    assert(vespa.adminserver.execute("ps auxwww | grep metricsproxy") =~ /-verbose:jni -verbose:gc/)

    assert(vespa.adminserver.execute("ps auxwww | grep logserver") =~ /verbose:gc/)

    assert(vespa.adminserver.execute("ps auxwww | grep docproc1/container\.0") =~ /MaxTenuringThreshold=13/)

    assert(vespa.adminserver.execute("ps auxwww | grep default/container\.0") =~ /MaxTenuringThreshold=10/)
  end

  def teardown
    stop
  end

end
