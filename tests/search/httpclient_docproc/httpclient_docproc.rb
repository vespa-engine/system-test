# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'document_set'
require 'json'

class HttpClientDocProcTest < SearchTest
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
    @valgrind = false
    set_owner("havardpe")
    set_description("Test feeding through HTTP client API to a docproc that spawns documents.")
  end

  def test_indexing_docproc_explicit_cluster_explicit_chain
    add_bundle(DOCPROC + "/SpawningMusicDocProc.java")
    container_cluster = Container.new("dpcluster1").
                            search(Searching.new).
                            documentapi(ContainerDocumentApi.new).
                            docproc(DocumentProcessing.new.chain(Chain.new("default").add(
                                    DocumentProcessor.new("com.yahoo.vespatest.SpawningMusicDocProc"))))
    output = deploy_app(SearchApp.new.
                cluster(SearchCluster.new.sd(SEARCH_DATA+"music.sd")).
                container(container_cluster).
                config(ConfigOverride.new("metrics.manager").add("reportPeriodSeconds", 3600)).
                monitoring("vespa", 300))
    start
    
    admin_node = vespa.adminserver
    @feed_file = dirs.tmpdir + "temp.feed.json"
    num_docs = 10000
    generate_documents(0, num_docs).write_vespafeed_json(@feed_file)
    gw = @vespa.container.values.first
    wait_for_application(gw, output)
    feedfile(@feed_file, {:client => :vespa_feed_client, :host => gw.name, :port => gw.http_port})

    # Don't care if we do not hit the spawned documents, we only care about feeding not getting stuck in this test.
    wait_for_hitcount("Document", num_docs)

    http = http_connection
    assert(verify_with_retries(http, {"PUT" => num_docs}))
  end

  def verify_with_retries(http, success_ops= {}, failed_ops = {})
    for i in 0..10
      if verify_metrics(http, success_ops, failed_ops)
        return true
      end
      sleep(0.5)
    end
    return verify_metrics(http, success_ops, failed_ops, true)
  end

  def verify_metrics(http, success_ops, failed_ops, errors = false)
    metrics_json = JSON.parse(http.get("/state/v1/metrics").body)
    metrics = metrics_json["metrics"]["values"]

    expect_metrics = {"OK" => success_ops, "REQUEST_ERROR" => failed_ops}
    actual_metrics = {"OK" => {}, "REQUEST_ERROR" => {}}
    for metric in metrics
      if metric["name"] == "feed.operations"
        status = metric["dimensions"]["status"]
        operation = metric["dimensions"]["operation"]
        value = metric["values"]["count"]
        actual_metrics[status][operation] = value
      end
    end

    if actual_metrics == expect_metrics
      return true
    else
      if errors
        puts "Expected feed metrics to be:"
        puts expect_metrics
        puts "But actually got:"
        puts actual_metrics
      end
      return false
    end
  end

  def http_connection
    container = vespa.container.values.first
    http = https_client.create_client(container.name, container.http_port)
    http.read_timeout=190
    http
  end

  def teardown
    stop
  end
end
