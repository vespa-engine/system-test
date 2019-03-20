# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'multi_provider_storage_test'
require 'gatewayxmlparser'

class VisitorTest < MultiProviderStorageTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
    @doc1 = Document.new("music", "id:storage_test:music:n=1234:1").
      add_field("title", "group 1")
    @doc2 = Document.new("music", "id:storage_test:music:n=1234:2").
      add_field("title", "group 2")
    @doc3 = Document.new("music", "id:storage_test:music:n=1234:3").
      add_field("title", "group 3")
    @doc4 = Document.new("music", "id:storage_test:music:n=5678:1").
      add_field("title", "group 3")
    @doc5 = Document.new("music", "id:storage_test:music:n=5678:2").
      add_field("title", "group 3")
    @timestart1 = 0
    @timestart2 = 0
    @timebeforeremove = 0
    @timeafterremove = 0
    @timeend = 0
  end

  def self.testparameters
    { "PROTON" => { :provider => "PROTON" },
      "DUMMY" => { :provider => "DUMMY", :nightly => true } }
  end

  def doInserts
    puts "Insert - START"
    vespa.document_api_v1.put(@doc1)
    vespa.document_api_v1.put(@doc2)
    vespa.document_api_v1.put(@doc3)
    vespa.document_api_v1.remove("id:storage_test:music:n=1234:3")
    vespa.document_api_v1.put(@doc4)
    vespa.document_api_v1.put(@doc5)
    puts "Insert - DONE"
  end

  def removeUser5678
    puts "Removing - START"
    vespa.document_api_v1.remove("id:storage_test:music:n=5678:1")
    vespa.document_api_v1.remove("id:storage_test:music:n=5678:2")
    puts "Removing - DONE"
  end

  def visitBogusSelection()
    args = " --selection \"bogus selection\""

    result = vespa.adminserver.execute("vespa-visit --xmloutput" + args,
        :exceptiononfailure => false)
    assert(result =~ /Illegal document selection string/, result);
  end

  def verifyNoDistributorsError(message)
    expected = "Could not resolve"
    assert(message =~ /#{expected}/, message);
    assert(message =~ /Visitor aborted by user/, message);
  end

  def visitClusterDown()
    args = " --abortonclusterdown"

    result_java = vespa.adminserver.execute("vespa-visit" + args,
        :exceptiononfailure => false)
    verifyNoDistributorsError(result_java)
  end

  def visit(startTime, endTime, selection, buckets=nil, visitremoves=false, fieldset=nil, params = {})
    args = "--xmloutput"

    if (startTime != 0)
      args += " --from " + startTime.to_s + " "
    end
    if (endTime != 0)
      args += " --to " + endTime.to_s + " "
    end
    if (visitremoves == true)
      args += " --visitremoves "
    end
    if (fieldset != nil && fieldset != "")
      args += " --fieldset \"" + fieldset + "\" "
    end

    if (buckets != nil && buckets.length > 0)
      if (selection == nil || selection == "")
        selection = ""
      else
        selection = "(" + selection + ") and "
      end
      selection += "("
      buckets.each { |bucket|
        selection += " id.user = " + bucket.to_s + " or "
      }
      selection = selection.chop
      selection = selection.chop
      selection = selection.chop
      selection += ")"
    end

    if (selection != nil && selection != "")
      args += " --selection \"" + selection + "\" "
    end

    params.each { |key,value|
      args += " --libraryparam " + key + " \"" + value + "\"";
    }

    java_xml = vespa.adminserver.execute("vespa-visit " + args)
    java_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <result>" + java_xml + "</result>"

    puts "full xml:\n====================="
    puts java_xml
    puts "==================="

    parser_java = GatewayXMLParser.new(java_xml)
    parser_java.documents.sort! {|a,b| a.documentid <=> b.documentid}

    return parser_java.documents
  end

  # Start visitor and check how many docs we get back
  def checkVisiting(buckets, startTime, endTime, selection)
    puts "* checkVisiting() buckets:" + buckets.inspect + " start:" + startTime.to_s + " end:" + endTime.to_s + " selection:" + selection

    results = visit(startTime, endTime, selection, buckets)

    puts " => " + results.length.to_s + " documents visited"

    return results.length
  end

  def doComplexInserts
    puts "Complexinsert - START"

    @timestart1 = Time.new.to_i
    puts "Put doc1 at " + Time.new.to_i.to_s
    vespa.document_api_v1.put(@doc1)

    sleep 2
    @timestart2 = Time.new.to_i
    sleep 2

    puts "Put doc2 at " + Time.new.to_i.to_s
    vespa.document_api_v1.put(@doc2)
    puts "Put doc3 at " + Time.new.to_i.to_s
    vespa.document_api_v1.put(@doc3)

    sleep 2
    @timebeforeremove = Time.new.to_i
    sleep 2

    puts "Remove doc3 at " + Time.new.to_i.to_s
    vespa.document_api_v1.remove("id:storage_test:music:n=1234:3")

    # StorageGateway should not return SOAP_FAULT in case of remove on NOT_FOUND
    vespa.document_api_v1.remove("id:ns:music:n=1234:does_not_exist")

    sleep 2
    @timeafterremove = Time.new.to_i
    sleep 2

    puts "Put doc4 at " + Time.new.to_i.to_s
    vespa.document_api_v1.put(@doc4)
    puts "Put doc5 at " + Time.new.to_i.to_s
    vespa.document_api_v1.put(@doc5)

    sleep 2
    @timeend = Time.new.to_i
    puts "Complexinsert - DONE at " + @timeend.to_s
  end

  def test_visitsomebuckets
    doInserts()

    puts "Starting visiting NOT including REMOVES"
    # Visit one bucket with and one buckets without docs, don't include REMOVES
    result = visit(0, 0, "", [ 1234, 45 ])
    assert_equal(2, result.size, result)

    assert_equal(@doc1, result[0])
    assert(!result[0].isRemoved, result[0])
    assert_equal(@doc2, result[1])
    assert(!result[1].isRemoved, result[1])

    puts "Starting visiting including REMOVES"

    # Visit one bucket with and one buckets without docs, include REMOVES
    result = visit(0, 0, "", [ 1234, 45 ], true)
    assert_equal(3, result.size)

    assert_equal(@doc1, result[0])
    assert(!result[0].isRemoved, result[0])
    assert_equal(@doc2, result[1])
    assert(!result[1].isRemoved, result[1])
    assert_equal("id:storage_test:music:n=1234:3", result[2].documentid)
    assert(result[2].isRemoved, result[2])
  end


  def test_visitallbuckets
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

    assert_equal(correctdocs.sort, visiteddocs.sort)
  end

  def test_visitbucketsselection
    doInserts()

    puts "* Select DocType(music) => all"

    numResults = checkVisiting([], 0, 0, "music")
    assert_equal(4, numResults) # get same results as in test_visitallbuckets

    puts "* Select music.title==\"group 3\" => 2 docs"

    numResults = checkVisiting([], 0, 0, "music.title==\\\"group 3\\\"")
    assert_equal(2, numResults) # doc4 + doc5, not doc3 (removed)
  end

  def test_visitgroupdocs
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:1"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:2"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:3"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=mygroup:4"))

    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=yourgroup:1"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=yourgroup:2"))
    vespa.document_api_v1.put(Document.new("music", "id:ns:music:g=yourgroup:3"))

    results = visit(0, 0, "id.group = \\\"mygroup\\\"", [])
    assert_equal(4, results.length)
    assert_equal("id:ns:music:g=mygroup:1", results[0].documentid)
    assert_equal("id:ns:music:g=mygroup:2", results[1].documentid)
    assert_equal("id:ns:music:g=mygroup:3", results[2].documentid)
    assert_equal("id:ns:music:g=mygroup:4", results[3].documentid)

    results = visit(0, 0, "id.group = \\\"yourgroup\\\"", [])
    assert_equal(3, results.length)
    assert_equal("id:ns:music:g=yourgroup:1", results[0].documentid)
    assert_equal("id:ns:music:g=yourgroup:2", results[1].documentid)
    assert_equal("id:ns:music:g=yourgroup:3", results[2].documentid)
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

  def test_visitfieldsets
    doc = Document.new("music", "id:test:music::test:test").
      add_field("title", "mytitle").
      add_field("band", "myband").
      add_field("body", "mybody")

    vespa.document_api_v1.put(doc)

    results = visit(0, 0, "", [], false, "[header]")
    assert_equal(1, results.length)
    assert_equal("mytitle", results[0].attributes["title"])
    assert_equal("myband", results[0].attributes["band"])
    assert_equal("mybody", results[0].attributes["body"])

    results = visit(0, 0, "", [], false, "music:title,body")
    assert_equal(1, results.length)
    assert_equal("mytitle", results[0].attributes["title"])
    assert_equal(nil, results[0].attributes["band"])
    assert_equal("mybody", results[0].attributes["body"])
  end

  def test_visittimestamp
    doc = Document.new("music", "id:test:music::test:test")
    vespa.document_api_v1.put(doc)

    results = visit(0, 0, "", [])
    assert_equal(1, results.length)
    assert(results[0].lastmodified != 0)
  end

  def test_visit_bucket_bogus_selection
    doInserts()

    visitBogusSelection()
  end

  def test_visit_all_distributors_down
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting([], 0, 0, "")
    puts "numResults before insert is " + numResults.to_s
    assert_equal(0, numResults)

    doInserts()

    # Run a visitor when all is ok
    numResults = checkVisiting([], 0, 0, "")
    assert_equal(4, numResults)

    vespa.storage["storage"].distributor["0"].stop
    vespa.storage["storage"].distributor["1"].stop

    vespa.storage["storage"].wait_until_cluster_down

    # Try to run a visitor when the distributor is down => should fail
    visitClusterDown()
  end

  def test_visit1of2storagenodesdown
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting([], 0, 0, "")
    puts "0 numResults = " + numResults.to_s
    assert_equal(0, numResults)

    doInserts()

    # Run a visitor when all is ok
    numResults = checkVisiting([], 0, 0, "")
    puts "1 numResults = " + numResults.to_s
    assert_equal(4, numResults)

    vespa.stop_content_node("storage", "1")

    # Run a visitor again when storage node has stopped
    numResults = checkVisiting([], 0, 0, "")
    puts "2 numResults = " + numResults.to_s
    assert_equal(4, numResults)
  end

  def test_visit1of2distributorsdown
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting([], 0, 0, "")
    puts "0 numResults = " + numResults.to_s
    assert_equal(0, numResults)

    doInserts()

    # Run a visitor when all is ok
    numResults = checkVisiting([], 0, 0, "")
    puts "1 numResults = " + numResults.to_s
    assert_equal(4, numResults)

    vespa.storage["storage"].distributor["1"].stop

    vespa.storage["storage"].wait_until_ready(30, ["1"])

    # Run a visitor again when distributor has stopped
    numResults = checkVisiting([], 0, 0, "")
    puts "2 numResults = " + numResults.to_s
    assert_equal(4, numResults)
  end

  def test_visitremoves
    doInserts()

    result = visit(0, 0, "", [])
    assert_equal(4, result.length)

    result = visit(0, 0, "", [], true)
    assert_equal(5, result.length)

    removeUser5678()

    result = visit(0, 0, "", [])
    assert_equal(2, result.length)

    result = visit(0, 0, "", [], true)
    assert_equal(5, result.length)
  end

  def teardown
    stop
  end
end
