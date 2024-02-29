# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class AttributeVisitorTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").enable_document_api)
    start
    @doc1 = Document.new("music", "id:storage_test:music:n=1234:1")
  end


  def doInserts
    puts "Insert - START"
    vespa.document_api_v1.put(@doc1)
    puts "Insert - DONE"
  end

  def test_visit_empty_attribute()
    doInserts
    result = vespa.adminserver.execute("vespa-visit --xmloutput")
    puts "Result = " + result.to_s
    assert(result !~ /twit_lkcnt/)
    assert(result !~ /twit_ikcnt/)
    assert(result !~ /<twit_skcnt/)
    assert(result !~ /twit_dkcnt/)
  end

  def teardown
    stop
  end
end
