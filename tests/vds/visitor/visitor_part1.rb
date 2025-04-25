# Copyright Vespa.ai. All rights reserved.

require 'vds/visitor/visitor'

class VisitorPart1Test < VisitorTest

  def test_visit_some_buckets
    doInserts()

    puts "Starting visiting NOT including REMOVES"
    # Visit one bucket with and one buckets without docs, don't include REMOVES
    result = visit(0, 0, "", [ 1234, 45 ])
    assert_equal(2, result.size, result)

    assert_equal(@doc1.documentid, result[0]['id'])
    assert_equal(@doc2.documentid, result[1]['id'])

    puts "Starting visiting including REMOVES"
    # Visit one bucket with and one buckets without docs, include REMOVES
    result = visit(0, 0, "", [ 1234, 45 ], true)
    assert_equal(3, result.size)

    assert_equal(@doc1.documentid, result[0]['id'])
    assert_equal(@doc2.documentid, result[1]['id'])
    assert_equal("id:storage_test:music:n=1234:3", result[2]['remove'])
  end

  def test_visit_all_buckets
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting([], 0, 0, "")
    puts "numResults before insert is " + numResults.to_s
    assert_equal(0, numResults)

    doInserts()

    numResults = checkVisiting([], 0, 0, "")
    puts "numResults after insert is " + numResults.to_s

    puts "Starting main visitor"

    visiteddocs = visit(0, 0, "", [])
    correctdocs = [ @doc1, @doc2, @doc4, @doc5 ]
    puts visiteddocs

    assert_equal(correctdocs.map { |doc| doc.documentid }.sort, visiteddocs.map { |doc| doc['id'] }.sort)
  end

  def test_visit_buckets_selection
    doInserts()

    puts "* Select DocType(music) => all"

    numResults = checkVisiting([], 0, 0, "music")
    assert_equal(4, numResults) # get same results as in test_visitallbuckets

    puts "* Select music.title==\"group 3\" => 2 docs"

    numResults = checkVisiting([], 0, 0, "music.title==\\\"group 3\\\"")
    assert_equal(2, numResults) # doc4 + doc5, not doc3 (removed)
  end

  def test_visit_group_docs
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:1"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:2"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:3"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:4"))

    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=yourgroup:1"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=yourgroup:2"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=yourgroup:3"))

    results = visit(0, 0, "id.group = \\\"mygroup\\\"", [])
    assert_equal(4, results.length)
    assert_equal("id:ns:music:g=mygroup:1", results[0]['id'])
    assert_equal("id:ns:music:g=mygroup:2", results[1]['id'])
    assert_equal("id:ns:music:g=mygroup:3", results[2]['id'])
    assert_equal("id:ns:music:g=mygroup:4", results[3]['id'])

    results = visit(0, 0, "id.group = \\\"yourgroup\\\"", [])
    assert_equal(3, results.length)
    assert_equal("id:ns:music:g=yourgroup:1", results[0]['id'])
    assert_equal("id:ns:music:g=yourgroup:2", results[1]['id'])
    assert_equal("id:ns:music:g=yourgroup:3", results[2]['id'])
  end

  def test_visit_ids
    doc = Document.new("music", "id:test:music::test:test").
      add_field("title", "mytitle").
      add_field("band", "myband").
      add_field("body", "mybody")

    vespa.document_api_v1.put(doc)

    result = vespa.storage["storage"].storage["0"].execute("vespa-visit --xmloutput --printids")
    assert(result.index("mytitle") == nil)
    assert(result.index("myband") == nil)
    assert(result.index("mybody") == nil)
  end

  def test_visit_field_sets
    doc = Document.new("music", "id:test:music::test:test").
      add_field("title", "mytitle").
      add_field("band", "myband").
      add_field("body", "mybody")

    vespa.document_api_v1.put(doc)

    results = visit(0, 0, "", [], false, "[all]")
    assert_equal(1, results.length)
    assert_equal("mytitle", results[0]['fields']["title"])
    assert_equal("myband", results[0]['fields']["band"])
    assert_equal("mybody", results[0]['fields']["body"])

    results = visit(0, 0, "", [], false, "music:title,body")
    assert_equal(1, results.length)
    assert_equal("mytitle", results[0]['fields']["title"])
    assert_equal(nil, results[0]['fields']["band"])
    assert_equal("mybody", results[0]['fields']["body"])
  end

end
