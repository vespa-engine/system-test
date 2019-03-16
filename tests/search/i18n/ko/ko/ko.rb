# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Ko < IndexedSearchTest
  def setup
    set_owner("johansen")
    set_description("Test of Korean indexing")
    deploy_app(SearchApp.new.sd(selfdir+"cjk.sd"))
    start
  end

  def test_cjk
    feed_and_wait_for_docs("cjk", 33, :file => SEARCH_DATA+"cjk.30.xml")
    wait_for_hitcount("query=sddocname:cjk", 33)

    puts "Query: One term queries, korean"
    assert_hitcount("query=content:%EC%9D%B4%EB%AF%B8&language=ko", 1)
    assert_hitcount("query=content:%EC%88%98%EC%9D%98&language=ko", 4)
    assert_hitcount("query=content:%EC%A0%9C%EC%A0%95&language=ko", 1)

    puts "Query: Two term queries, korean"
    assert_hitcount("query=content:%EC%97%AC%EA%B8%B0%EC%84%9C%EB%8A%94&language=ko", 1)
    assert_hitcount("query=content:%EA%B8%B0%EB%AC%BC%EB%A7%88%EB%8B%A4+content:%ED%96%89%EB%A7%88%EC%9D%98+content:%EB%B2%94%EC%9C%84%EA%B0%80+content:%EC%A0%9C%ED%95%9C%EB%90%98%EC%96%B4&language=ko", 1)
  end

  def teardown
    stop
  end

end
