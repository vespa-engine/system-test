# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'document_set'

class MassiveHttpClientFeedingTest < SearchTest
  
  DOCUMENTS = 100000
  
  def generate_documents(docid_begin, num_docs)
    ds = DocumentSet.new()
    for i in docid_begin...docid_begin + num_docs do
      doc = Document.new("music", "id:music:music::" + "%07d" % i)
      doc.add_field("title", "Ronny och Ragge");
      ds.add(doc)
    end
    return ds
  end

  def setup
    set_owner("jonmv")
    set_description("Verifies that a container can handle more feed threads than it has thread.")
    @valgrind = false

    @feed_file = dirs.tmpdir + "temp.feed.json"
    generate_documents(0, DOCUMENTS).write_vespafeed_json(@feed_file)
  end

  def test_vespa_feed_client_with_tls
    gw = deploy_test_app
    feedfile(@feed_file, {:client => :vespa_feed_client, :host => gw.name, :port => gw.http_port,
                          :numconnections => 8, :max_streams_per_connection => 32, })

    # Don't care if we do not hit the spawned documents, we only care about feeding not getting stuck in this test.
    wait_for_hitcount("ronny", DOCUMENTS)
  end

  def test_vespa_feed_client_without_tls
    gw = deploy_test_app
    feedfile(@feed_file, {:client => :vespa_feed_client, :host => gw.name, :port => gw.http_port + 1,
                          :numconnections => 8, :max_streams_per_connection => 32, :disable_tls => true})

    # Don't care if we do not hit the spawned documents, we only care about feeding not getting stuck in this test.
    wait_for_hitcount("ronny", DOCUMENTS)
  end

  private
  def deploy_test_app
    container_port = Environment.instance.vespa_web_service_port
    container_cluster = Container.new("dpcluster1").
      component(AccessLog.new("disabled")).
      jvmoptions("-Xms4096m -Xmx4096m").
      search(Searching.new).
      documentapi(ContainerDocumentApi.new).
      config(ConfigOverride.new("container.handler.threadpool").add("maxthreads", 4)).
      http(Http.new.
        server(
          Server.new('default', container_port)).
        server(
          Server.new('plain-text-port', container_port + 1).
            config(ConfigOverride.new('jdisc.http.connector').
              add('implicitTlsEnabled', 'false')))) # Disable implicit TLS when Vespa mTLS setup is enabled
    output = deploy_app(SearchApp.new.
      cluster(SearchCluster.new.sd(SEARCH_DATA+"music.sd")).
      container(container_cluster))
    start

    gw = @vespa.container.values.first
    wait_for_application(gw, output)
    gw
  end

  def teardown
    stop
  end
end
