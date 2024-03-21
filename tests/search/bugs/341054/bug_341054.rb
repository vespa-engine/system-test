# coding: utf-8
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

# encoding: utf-8
require 'indexed_search_test'

class Bug_341054 < IndexedSearchTest

  def setup
    set_owner("johansen")
    set_description("Test for bug #341054 (utf-8 replacement char in output)")
    deploy_app(SearchApp.new.sd(selfdir+"knowledge.sd"))
    start
  end

  def test_bug_341054
    feed_and_wait_for_docs("knowledge", 1, :file => selfdir+"onedoc.db.utf8.json")

    puts "Query: basic test"
    result = to_utf8(search("query=ipod&language=zh-hant").xmldata).split("\n")
    result.delete_if {|line| !line.match('"bestanswer"') }
    result.delete_if {|line| line.match('�') }
    assert_equal(1,result.length)

  end

  def teardown
    stop
  end

end
