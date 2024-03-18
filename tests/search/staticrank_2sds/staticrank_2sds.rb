# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class StaticRank_2SDs < IndexedSearchTest

  def setup
    set_owner("geirst")
    set_description("Test staticrank with two schemas")
    deploy_app(SearchApp.new.sd(selfdir+"one.sd").sd(selfdir+"two.sd"))
    start
  end

  def test_staticrank_2sds
    feed(:file => selfdir+"one-and-two.4.json")
    wait_for_hitcount("query=sddocname:one", 2)
    wait_for_hitcount("query=sddocname:two", 2)

    puts "Query: First doctype"
    assert_result("query=document", selfdir+"document.result.json", nil, ["relevancy", "about"])

    puts "Query: Second doctype"
    assert_result("query=foo", selfdir+"foo.result.json", nil, ["relevancy", "title"])

    puts "Query: Both doctypes"
    assert_result("query=document+foo&type=any", selfdir+"document-foo.result.json", nil, ["relevancy", "surl"])

  end

  def teardown
    stop
  end

end
