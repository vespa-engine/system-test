# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class SimpleInheritance < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
  end

  def test_simple_doctype_inheritance
    deploy_app(SearchApp.new.sd(selfdir+"base.sd").sd(selfdir+"derived.sd"))
    #vespa.adminserver.logctl("configproxy:com.yahoo.vespa.config", "debug=on")
    #vespa.adminserver.logctl("configserver", "debug=on")
    start
    feed_and_wait_for_docs("derived", 1, :file => selfdir+"testsimpleinheritance.json")

    attrtocompare =  ["sddocname","field1","field2","field3","field4","url"]

    puts "Query: Test that field 1 is present in base and derived"
    assert_result("query=field1:f1&search=base", selfdir+"1.json", "sddocname", attrtocompare)

    puts "Query: Test that field 2 is present in base"
    assert_result("query=field2:f2d2&search=base", selfdir+"2.json", nil, attrtocompare)

    puts "Query: Test that field 1 is present in derived"
    assert_result("query=field1:f1&search=derived", selfdir+"3.json", nil, attrtocompare)

    puts "Query: Test that field 2 is present in derived via base"
    assert_result("query=field2:f2d1&search=base", selfdir+"4.json", nil, attrtocompare)
  end

  def test_really_simple_inheritance
    deploy_app(SearchApp.new.sd(selfdir+"simple/base.sd").sd(selfdir+"simple/simple.sd"))
    start

    feed_and_wait_for_docs("simple", 1, :file => selfdir+"simple.json")

    puts "Query: Test that field 2 is present"
    assert_hitcount("query=field2:f2", 1)

    puts "Query: Test that field 1 is present"
    assert_hitcount("query=field1:f1", 1)
  end

  def teardown
    stop
  end

end
