# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class CNHighlighting < IndexedSearchTest

  def setup
    set_owner("nobody")
    set_description("Test of a particular highlighting behavior in Chinese launguage")
    deploy_app(SearchApp.new.sd(selfdir+"cn.sd"))
    start
  end

  def test_cn_highlighting
    feed_and_wait_for_docs("cn", 2, :file => selfdir+"input.xml", :maxpending => 1)

    puts "Illustrate the problem in English"
    assert_result("query=%22lord+of+the+rings%22&language=zh-hans", selfdir+"result0.xml")

    puts "Similar problem in Chinese"
    assert_result("query=%22%E5%85%89%E9%98%B4%E7%9A%84%E6%95%85%E4%BA%8B%22&language=zh-hans", selfdir+"result1.xml")
  end

  def teardown
    stop
  end

end
