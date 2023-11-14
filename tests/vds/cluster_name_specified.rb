# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class Cluster_Name_Specified < VdsTest

  def setup
    @valgrind=false
    set_owner("vekterli")

    deploy_app(
               StorageApp.new.enable_document_api.storage_cluster(
                 StorageCluster.new("nonstandard").default_group).sd(VDS + "/schemas/music.sd").
               transition_time(0));
    start
  end

  def test_basicfunctionality
    doc = Document.new("music", "id:storage_test:music:n=1234:0").
      add_field("title", "title")
    vespa.document_api_v1.put(doc)

    # Get the document we just stored.
    doc2 = vespa.document_api_v1.get("id:storage_test:music:n=1234:0")
    assert_equal(doc, doc2)

    # Get non-existing document, check that we get nil
    assert_equal(nil, vespa.document_api_v1.get("id:storage_test:music:n=56789:0"))

    # Stat non-existing document, check that we get empty list
    res = vespa.storage["nonstandard"].storage["0"].stat("id:storage_test:music:n=56789:0")
    assert_equal(0, res.size)

    # Remove non-existing document
    vespa.document_api_v1.remove("id:storage_test:music:n=56789:0")

    # Get the old document again.
    doc2 = vespa.document_api_v1.get("id:storage_test:music:n=1234:0")
    assert_equal(doc, doc2)

    # Remove it
    vespa.document_api_v1.remove("id:storage_test:music:n=1234:0")
    vespa.document_api_v1.remove("id:storage_test:music:n=1234:0")
    # Remove it - twice
    vespa.document_api_v1.remove("id:storage_test:music:n=1234:0")
    vespa.document_api_v1.remove("id:storage_test:music:n=1234:0")

    # Get the old document again.
    assert_equal(nil, vespa.document_api_v1.get("id:storage_test:music:n=1234:0"))

    # Stat removed document, check that we get empty list
    res = vespa.storage["nonstandard"].storage["0"].stat("id:storage_test:music:n=1234:0")
    assert_equal("DELETED", res["0"]["status"])

    # Stat document that is not stored (but bucket is)
    res = vespa.storage["nonstandard"].storage["0"].stat("id:storage_test:music:n=1234:2")
    assert_equal(0, res.size())

    doc = Document.new("music", "id:storage_test:music:n=5678:0")
    3.times { | i |
      doc.add_field("title", "title-#{i}")
      vespa.document_api_v1.put(doc)
    }

    doc2 = vespa.document_api_v1.get("id:storage_test:music:n=5678:0")
    assert_equal(doc, doc2)
  end

  def teardown
    stop
  end
end

