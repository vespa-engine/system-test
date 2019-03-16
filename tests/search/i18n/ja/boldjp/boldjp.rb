# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class BoldJp < IndexedSearchTest

  def nightly?
    true
  end

  def setup
    set_owner("johansen")
    set_description("Test with long tokenz on 100byte boundary")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    start
  end

  def test_bold_jp
    feed_and_wait_for_docs("simple", 2, :file => selfdir+"simple.docs.2.xml")

    filter = /"title"|"description"/
    puts "Query: basic test"
    assert_result("query=test", selfdir+"q1.result", filter)

    puts "Query: japanese text"
    assert_result("query=%E9%A6%99%E5%B7%9D%E7%9C%8C%E7%94%A3&language=ja", selfdir+"q2.result", filter)

    puts "Query: japanese text, two words reverse"
    assert_result("query=%E7%9C%8C%E7%94%A3+%E9%A6%99%E5%B7%9D&language=ja", selfdir+"q2.result", filter)

    puts "Query: japanese letters"
    assert_result("query=%E9%A6%99+%E5%B7%9D+%E7%9C%8C&language=ja", selfdir+"q4.result", filter)


  end

  def teardown
    stop
  end

end
