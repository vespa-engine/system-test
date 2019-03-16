# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Zh < IndexedSearchTest

  def setup
    set_owner("yngve")
    set_description("Test of Chinese indexing")
    deploy_app(SearchApp.new.sd(selfdir+"cjk.sd"))
    start
  end

  def test_zh_hans
    feed_and_wait_for_docs("cjk", 33, :file => SEARCH_DATA+"cjk.30.xml")
    wait_for_hitcount("query=sddocname:cjk", 33)

    puts "Query: One term queries, chinese"
    assert_hitcount("query=content:%E5%88%A4&language=zh-hans", 1)
    assert_hitcount("query=content:%E4%BB%98%E5%87%BA&language=zh-hans", 1)

    puts "Query: Multiple term queries, chinese"
    assert_hitcount("query=content:%E6%B0%94%E5%B0%BD%E6%8F%90%E5%8F%96&language=zh-hans", 1)
    assert_hitcount("query=content:%E5%9B%B4%E6%A3%8B%E6%B2%A1%E6%9C%89%E7%87%95&language=zh-hans", 1)
  end

  def teardown
    stop
  end

end
