# Copyright Vespa.ai. All rights reserved.
require 'container_test'
require 'app_generator/container_app'
require 'app_generator/http'

class JvmTuning < ContainerTest

  def can_share_configservers?
    false
  end

  def setup
    set_owner("musum")
    set_description("Tests setting JVM options in services.xml or with environment variables")
    @app = ContainerApp.new.
               container(Container.new.
                           jvmgcoptions("-XX:+UseG1GC -XX:MaxTenuringThreshold=10").
                           jvmoptions('-Dfoo=bar -Dvespa_foo="foo og bar" -Xms256m -Xmx256m ' +
                                      '-XX:+PrintCommandLineFlags')).
               container(Container.new("docproc1").
                           jvmoptions("-XX:+PrintCommandLineFlags -Xms256m -Xmx256m").
                           jvmgcoptions("-XX:MaxTenuringThreshold=13").
                           docproc(DocumentProcessing.new.chain(Chain.new("docproc1-chain").add(DocProc.new("com.yahoo.vespatest.WorstMusicDocProc")))).
                           http(Http.new.server(Server.new("server1", 5000))))
  end

  def test_jvmtuning
    container_deploy(@app, {})

    override_environment_setting(vespa.configservers["0"], "VESPA_CONFIGSERVER_JVMARGS", "-verbose:gc -verbose:jni")
    override_environment_setting(vespa.adminserver, "VESPA_CONFIGPROXY_JVMARGS", "-verbose:jni -verbose:gc")
    vespa.configservers["0"].stop_configserver
    vespa.configservers["0"].start_configserver
    add_bundle(DOCPROC+"/WorstMusicDocProc.java")
    container_deploy(@app, {})
    start(@app)

    assert(vespa.adminserver.execute("ps auxwww | grep configserver") =~ /-verbose:gc -verbose:jni/)
    assert(vespa.adminserver.execute("ps auxwww | grep config.proxy") =~ /-verbose:jni -verbose:gc/)

    assert(vespa.adminserver.execute("ps auxwww | grep docproc1/container\.0") =~ /MaxTenuringThreshold=13/)

    assert(vespa.adminserver.execute("ps auxwww | grep default/container\.0") =~ /MaxTenuringThreshold=10/)
  end


end
