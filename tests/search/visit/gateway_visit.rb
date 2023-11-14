# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'

class GatewayVisitTest < SearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").enable_document_api)
    start
  end


  def doInserts
    puts "Insert - START"

    docid = "id:systemtest:music::1"
    doc1 = Document.new("music", docid).
           add_field("twit_lkcnt", "987654321").
           add_field("twit_ikcnt", "12345").
           add_field("twit_dkcnt", "42.42").
           add_field("twit_skcnt", "foobar")
    vespa.document_api_v1.put(doc1)
    puts "Insert - DONE"
  end

  def test_visit_some_docs()
    doInserts
    res = vespa.document_api_v1.visit(:selection => "music", :fieldSet => "music:[document]", :cluster => "search", :wantedDocumentCount => 10)
    puts "RES: #{res}"
  end

  def teardown
    stop
  end
end
