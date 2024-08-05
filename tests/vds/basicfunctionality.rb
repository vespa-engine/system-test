# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class BasicFunctionality < VdsTest

  def setup
    @valgrind=false
    deploy_app(default_app)
    set_owner("vekterli")
    start
  end

  def test_partialupdatethroughvespafeeder
    # Put document
    doc = Document.new("music", "id:storage_test:music:n=1234:vespafeeder")
    vespa.document_api_v1.put(doc)

    feedfile(selfdir + "data/partialupdate.json")

    # Get the document we just stored.
    doc2 = vespa.document_api_v1.get("id:storage_test:music:n=1234:vespafeeder")

    # Apply change to document object here and assert it is equal to
    # retrieved document.
    doc.add_field("title", "TestTitle").
        add_field("year", 1982).
	add_field("tracks", [ "track 1", "track 3" ]).
        add_field("popularity", { 0 => 3, 2 => -4, 4 => 89 })

    assert_equal(doc2, doc)
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
    res = vespa.storage["storage"].storage["0"].stat("id:storage_test:music:n=56789:0")
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
    res = vespa.storage["storage"].storage["0"].stat("id:storage_test:music:n=1234:0")
    assert_equal("DELETED", res["0"]["status"])

    # Stat document that is not stored (but bucket is)
    res = vespa.storage["storage"].storage["0"].stat("id:storage_test:music:n=1234:2")
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

