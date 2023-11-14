# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class TestTypes < IndexedSearchTest

  def setup
    set_owner("musum")
    set_description("Index different attribute types: string, integer, float, BLOB, timestamp, long, byte")
  end

  def test_types
    deploy_app(SearchApp.new.enable_document_api.sd(selfdir + "legacy/typetest.sd"))
    start
    run_test(selfdir + "legacy/testtypes.result.json")

    output = deploy_app(SearchApp.new.enable_document_api.sd(selfdir + "typetest.sd"))
    wait_for_reconfig(get_generation(output).to_i)
    run_test(selfdir + "testtypes.result.json")
  end

  def run_test(expected)
    doc_id = "id:test:typetest::http://this-is-a-host.com/path_name"
    feed_and_wait_for_docs("typetest", 1, :file => selfdir + "testtypes.1.xml")
    verify(expected)
    doc = vespa.document_api_v1.get(doc_id)
    vespa.document_api_v1.put(doc)
    verify(expected)
    res = vespa.document_api_v1.visit(:selection => "typetest", :fieldSet => "typetest:[document]", :cluster => "search")
    assert(res["documents"].size == 1)
    puts "Visit result : " + res["documents"][0].to_s
    vdoc = Document.create_from_json(res["documents"][0], "typetest")
    assert(vdoc.documentid == doc_id)
    vespa.document_api_v1.put(vdoc)
    verify(expected)
  end

  def verify(expected)
    # Query: String search
    assert_result("query=%2bstringfield:is%20%2bstringfield:a", expected)

    # Query: String search with exact match
    assert_result("query=ematchfield:this+HAS+to+be+like+this@@", expected)

    assert_hitcount("query=boolfield:true", 1)
    assert_hitcount("query=boolfield:false", 0)
    assert_hitcount('yql=select+%2A+from+sources+%2A+where+boolfield+contains+"true"%3B', 1)
    assert_hitcount('yql=select+%2A+from+sources+%2A+where+boolfield+contains+"false"%3B', 0)
    assert_hitcount('yql=select+%2A+from+sources+%2A+where+boolfield=true%3B', 1)
    assert_hitcount('yql=select+%2A+from+sources+%2A+where+boolfield=false%3B', 0)
  end

  def teardown
    stop
  end

end
