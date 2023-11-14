# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class VdsBasicFeeding < VdsTest

  def setup
    set_owner("valerijf")
  end

  def test_docid
    deploy_app(default_app)
    start

    # Put document using vespa-feeder
    feedfile(selfdir+"data/docid.xml")

    docid = "id:test:music::http://localhost:5810/?query=foo&hits=1"
    # Create document here for comparison
    exp_doc = Document.new("music", docid).
      add_field("title", "QRS url 1").
      add_field("artist", "Unknown artist")
    # Get a document we just stored.
    doc = vespa.document_api_v1.get(docid)
    assert(doc, "did not find #{docid} in backend")
    assert_equal(exp_doc, doc)

    docid = "id:test:music::http://localhost:5810/?query=bar&hits=1"
    # Get a document we just stored.
    doc2 = get_doc_as_xml(docid)
    assert(doc2, "did not find #{docid} in backend")
    exp_doc2 = Document.new("music", docid).
      add_field("title", "QRS url 2").
      add_field("artist", "Known artist")

    assert_equal(exp_doc2, Document.create_from_xml(doc2.root))
    assert(doc2.root.attributes["lastmodifiedtime"].to_i > 0)
  end

  def get_doc_as_xml(id)
    output = vespa.storage['storage'].storage["0"].execute("vespa-get --xmloutput \"#{id}\"")
    REXML::Document.new(output)
  end

  def test_arrays
    deploy_app(default_app)
    start

    # Put docment with array attribute using vespa-feeder
    feedfile(selfdir+"data/array.xml")

    # Create the same document for comparison
    doc1 = Document.new("music",
                        "id:music:music::http://music.yahoo.com/bobdylan/BestOf").
      add_field("url", "http://music.yahoo.com/bobdylan/BestOf").
      add_field("title", "Best of Bob Dylan").
      add_field("artist", "Bob Dylan").
      add_field("year",  1997).
      add_field("tracks", [ "Track 1", "Track 2", "Track 3" ])

    # Get the documents we just stored using vespa-feeder
    doc2 = vespa.document_api_v1.get("id:music:music::http://music.yahoo.com/bobdylan/BestOf")

    assert_equal(doc1, doc2)

    # Put document with array attribute using document API
    doc3 = Document.new("music", "id:storage_test:music:n=1234:soap").
      add_field("url", "http://music.yahoo.com/soap").
      add_field("title", "SoapTitle").
      add_field("artist", "Vespa").
      add_field("tracks", [ "123", "456", "789" ])

    vespa.document_api_v1.put(doc3)

    # Get the documents we just stored using document API
    doc4 = vespa.document_api_v1.get("id:storage_test:music:n=1234:soap")

    assert_equal(doc3, doc4)
  end

  def test_weightedset
    deploy_app(default_app)
    start

    # Put document with array attribute using vespa-feeder
    feedfile(selfdir+"data/weightedset.xml")

    # Create the same document for comparison
    doc1 = Document.new("music",
      "id:music:music::http://music.yahoo.com/bobdylan/BestOf").
      add_field("url", "http://music.yahoo.com/bobdylan/BestOf").
      add_field("title", "Best of Bob Dylan").
      add_field("artist", "Bob Dylan").
      add_field("year",  1997).
      add_field("popularity", { 0 => 10, 1 => 11, 2 => 12 })

    # Get the documents we just stored using vespa-feeder
    doc2 = vespa.document_api_v1.get("id:music:music::http://music.yahoo.com/bobdylan/BestOf")

    assert_equal(doc1, doc2)

    # Put document with weightedset attribute using document API
    doc3 = Document.new("music", "id:storage_test:music:n=1234:soap").
      add_field("url", "http://music.yahoo.com/soap").
      add_field("title", "SoapTitle").
      add_field("artist", "Vespa").
      add_field("popularity", { 3 =>20, 4 => 31, 5 => 42 })

    vespa.document_api_v1.put(doc3)

    # Get the documents we just stored using document API
    doc4 = vespa.document_api_v1.get("id:storage_test:music:n=1234:soap")

    assert_equal(doc3, doc4)
  end

  def test_mixed_case_doctype_vespafeeder
    deploy_app(default_app.sd(VDS + "schemas/MiXedCase.sd"))
    start

    set_owner("vekterli")
    feedfile(selfdir+"data/mixedcase.xml")

    doc1 = Document.new("MiXedCase", "id:MiXedCase:MiXedCase::DaisyDaisy").
      add_field("title", "title #1").
      add_field("description", "description #1")

    doc2 = Document.new("MiXedCase", "id:MiXedCase:MiXedCase::GiveMeYourAnswerTrue").
      add_field("title", "title #2").
      add_field("description", "description #2")

    doc1_get = vespa.document_api_v1.get("id:MiXedCase:MiXedCase::DaisyDaisy")
    doc2_get = vespa.document_api_v1.get("id:MiXedCase:MiXedCase::GiveMeYourAnswerTrue")

    assert_equal(doc1, doc1_get)
    assert_equal(doc2, doc2_get)
  end

  def test_mixed_case_doctype_vespa_feed_client
    deploy_app(default_app.sd(VDS + "schemas/MiXedCase.sd"))
    start

    set_owner("vekterli")
    feedfile(selfdir+"data/mixedcase.xml", :client => :vespa_feeder)

    doc1 = Document.new("MiXedCase", "id:MiXedCase:MiXedCase::DaisyDaisy").
      add_field("title", "title #1").
      add_field("description", "description #1")

    doc2 = Document.new("MiXedCase", "id:MiXedCase:MiXedCase::GiveMeYourAnswerTrue").
      add_field("title", "title #2").
      add_field("description", "description #2")

    doc1_get = vespa.document_api_v1.get("id:MiXedCase:MiXedCase::DaisyDaisy")
    doc2_get = vespa.document_api_v1.get("id:MiXedCase:MiXedCase::GiveMeYourAnswerTrue")

    assert_equal(doc1, doc1_get)
    assert_equal(doc2, doc2_get)
  end

  def teardown
    stop
  end
end

