# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'document_set'
require 'json'

class HttpClientDocProcTest < SearchTest

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
    
    @feed_file = dirs.tmpdir + "temp.feed.json"
    num_docs = 10000
    generate_documents(0, num_docs).write_vespafeed_json(@feed_file)
    container = @vespa.container.values.first
    wait_for_application(container, output)
    feedfile(@feed_file, {:client => :vespa_feed_client, :host => container.name, :port => container.http_port})

    # Don't care if we do not hit the spawned documents, we only care about feeding not getting stuck in this test.
    wait_for_hitcount("Document", num_docs)

    http = http_connection
    assert(verify_with_retries(http, num_docs))
  end

  def verify_with_retries(http, num_docs)
    for i in 0..20
      if verify_metrics(http, num_docs)
        true
      end
      sleep(0.5)
    end
    verify_metrics(http, num_docs, true)
  end

  def verify_metrics(http, num_docs, errors = false)
    metrics_json = JSON.parse(http.get("/state/v1/metrics").body)
    metrics = metrics_json["metrics"]["values"]

    actual_metrics = {"OK" => {}, "REQUEST_ERROR" => {}}
    for metric in metrics
      if metric["name"] == "feed.operations"
        status = metric["dimensions"]["status"]
        operation = metric["dimensions"]["operation"]
        value = metric["values"]["count"]
        if actual_metrics.has_key?(status) # Ignore 429
          actual_metrics[status][operation] = value
        end
      end
    end

    # We get num_docs + 1 or num_docs + 2 operations in metrics:
    num_docs_plus_1 = num_docs + 1 # + 1 for client "handshake"
    num_docs_plus_2 = num_docs + 2 # + 2 for client "handshake" and one extra for unknown reasons
    expected_metrics = {"OK" => {"PUT" => num_docs_plus_1},  "REQUEST_ERROR" => {}}
    expected_metrics_2 = {"OK" => {"PUT" => num_docs_plus_2},  "REQUEST_ERROR" => {}}
    if actual_metrics == expected_metrics or actual_metrics == expected_metrics_2
      true
    else
      if errors
        puts "Expected feed metrics to be:"
        puts expected_metrics
        puts "But actually got:"
        puts actual_metrics
      end
      false
    end
  end

  def generate_documents(docid_begin, num_docs)
    ds = DocumentSet.new()
    for i in docid_begin...docid_begin + num_docs do
      doc = Document.new("music", "id:music:music::" + "%07d" % i)
      doc.add_field("title", "Ronny och Ragge")
      ds.add(doc)
    end
    ds
  end

  def http_connection
    container = vespa.container.values.first
    http = https_client.create_client(container.name, container.http_port)
    http.read_timeout = 190
    http
  end

  def teardown
    stop
  end
end
