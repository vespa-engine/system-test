# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class GatewayVisitTest < IndexedOnlySearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def do_inserts
    docid = "id:systemtest:music::1"
    doc1 = Document.new("music", docid).
           add_field("twit_lkcnt", "987654321").
           add_field("twit_ikcnt", "12345").
           add_field("twit_dkcnt", "42.42").
           add_field("twit_skcnt", "foobar")
    vespa.document_api_v1.put(doc1)
  end

  def test_visit_some_docs()
    do_inserts
    res = vespa.document_api_v1.visit(:selection => "music", :fieldSet => "music:[document]", :cluster => "search", :wantedDocumentCount => 10)
  end

  def teardown
    stop
  end

end
