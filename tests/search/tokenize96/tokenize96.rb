# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Tokenize96 < IndexedSearchTest

  def nightly?
    true
  end

  def setup
    set_owner("johansen")
    set_description("Test with long tokenz on 100byte boundary")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    start
  end

  def test_tokenize96
    feed_and_wait_for_docs("simple", 2, :file => selfdir+"simple.docs.2.xml")

    fields = ["title", "description"]
    puts "Query: basic test"
    assert_result("query=title:test", selfdir+"doc1.result", nil, fields)

    puts "Query: japanese text"
    assert_result("query=description:%E9%A6%99%E5%B7%9D%E7%9C%8C%E7%94%A3&language=ja", selfdir+"doc1.result", nil, fields)

    puts "Query: japanese text, two words reverse"
    assert_result("query=description:%E7%9C%8C%E7%94%A3+description:%E9%A6%99%E5%B7%9D&language=ja", selfdir+"doc1.result", nil, fields)

    puts "Query: japanese letters"
    assert_result("query=description:%E9%A6%99+description:%E5%B7%9D+description:%E7%9C%8C&language=ja", selfdir+"doc2.result", nil, fields)

    puts "Query: long first word (96 bytes long)"
    assert_result("query=description:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx123456", selfdir+"doc1.result", nil, fields)

  end

  def teardown
    stop
  end

end
