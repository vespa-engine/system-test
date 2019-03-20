# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'streaming_search_test'

class LoadTypes < StreamingSearchTest

  def setup
    @valgrind=false
    set_owner("vekterli")

    app = SearchApp.new.
      enable_http_gateway.
      streaming().
      cluster(SearchCluster.new.sd(VDS+"/searchdefinitions/music.sd").
              num_parts(1).storage_cluster("storage")).
      storage(StorageCluster.new("storage", 1).
              group(NodeGroup.new(0, "mygroup").default_nodes(1, 0))).
      load_type(LoadType.new("foo"))
    deploy_app(app)
    start
  end

  def get_count_metric(metrics, field)
    mf = metrics[field]
    return mf['count'] if mf
    flunk("could not find metric field #{field} within metrics dumped: #{metrics}")
  end

  def run_vespa_get(args)
    vespa.storage['storage'].storage["0"].execute("vespa-get " + args).strip
  end

  def test_loadtypes
    doc = Document.new("music", "id:storage_test:music:n=1234:0").
      add_field("title", "title")
    vespa.document_api_v1.put(doc)

    # Get the document we just stored.
    doc2 = run_vespa_get("--printids --loadtype foo id:storage_test:music:n=1234:0")
    assert_equal(doc.documentid, doc2)

    # Remove it
    vespa.document_api_v1.remove("id:storage_test:music:n=1234:0")

    # Get the old document again.
    assert_equal(nil, vespa.document_api_v1.get("id:storage_test:music:n=1234:0"))

    result = search("query=sddocname:mail&streaming.userid=1234&streaming.loadtype=foo")
    puts result.to_s

    status = vespa.storage["storage"].distributor["0"].get_metrics_matching("vds.distributor.*ok")
    assert_equal(1, get_count_metric(status, "vds.distributor.puts.default.ok"))
    assert_equal(1, get_count_metric(status, "vds.distributor.gets.foo.ok"))
    assert_equal(1, get_count_metric(status, "vds.distributor.removes.default.ok"))
    assert_equal(1, get_count_metric(status, "vds.distributor.gets.default.ok"))

    status = vespa.storage["storage"].storage["0"].get_metrics_matching("vds.filestor.alldisks.allthreads.*")
    assert_equal(1, get_count_metric(status, "vds.filestor.alldisks.allthreads.get.foo.count"))
  end

  def teardown
    stop
  end
end

