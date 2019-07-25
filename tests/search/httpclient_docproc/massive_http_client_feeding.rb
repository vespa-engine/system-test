# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'document_set'

class MassiveHttpClientFeedingTest < SearchTest
  
  DOCUMENTS = 50000
  
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
    set_owner("valerijf")
    set_description("Verifies that a container can handle more feed threads than it has thread.")
    @valgrind = false
  end

  def test_massive_feeding
    container_cluster = Container.new("dpcluster1").
                            jvmargs("-Xms4096m -Xmx4096m").
                            search(Searching.new).
                            gateway(ContainerDocumentApi.new).
                            config(ConfigOverride.new("container.handler.threadpool").add("maxthreads", 50))
    output = deploy_app(SearchApp.new.
                cluster(SearchCluster.new.sd(SEARCH_DATA+"music.sd")).
                container(container_cluster))
    start
    
    admin_node = vespa.adminserver
    @feed_file = dirs.tmpdir + "temp.feed.xml"
    generate_documents(0, DOCUMENTS).write_vespafeed_xml(@feed_file)
    gw = @vespa.container.values.first
    wait_for_application(gw, output)
    feedfile(@feed_file, {:client => :vespa_http_client, :host => gw.name, :port => gw.http_port, :num_persistent_connections_per_endpoint => 500})

    # Don't care if we do not hit the spawned documents, we only care about feeding not getting stuck in this test.
    wait_for_hitcount("ronny", DOCUMENTS)
  end

  def teardown
    stop
  end
end
