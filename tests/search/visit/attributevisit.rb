# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class AttributeVisitorTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
    @doc1 = Document.new("music", "id:storage_test:music:n=1234:1")
  end

  def test_visit_empty_attribute
    vespa.document_api_v1.put(@doc1)
    result = vespa.adminserver.execute("vespa-visit")
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
