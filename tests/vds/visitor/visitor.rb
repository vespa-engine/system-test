# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'vds_test'
require 'gatewayxmlparser'

class VisitorTest < VdsTest

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
    result = vespa.adminserver.execute("vespa-visit --xmloutput" + args, { :exceptiononfailure => false, :stderr => true })
    assert(result =~ /Illegal document selection string/, result);
  end

  def verifyNoDistributorsError(message)
    expected = "Could not resolve"
    assert(message =~ /#{expected}/, message);
    assert(message =~ /Visitor aborted by user/, message);
  end

  def visitClusterDown()
    args = " --abortonclusterdown"
    result_java = vespa.adminserver.execute("vespa-visit" + args, { :exceptiononfailure => false, :stderr => true })
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

    results = visit(startTime, endTime, selection, buckets, :stderr => true)

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

  def teardown
    stop
  end
end
