# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Bug_253184 < IndexedSearchTest
  # Feature: use "index-to" with multiple indexes, some different, some common

  def setup
    set_owner("bratseth")
    deploy_app(SearchApp.new.sd(selfdir + "musicsearch.sd"))
    start
  end

  def test_indexto_several
    feed_and_wait_for_docs("musicsearch", 2, :file => selfdir+"musicsearch.2.xml")

    assert_field("query=all:one",     selfdir + "one.result.json", "f1")
    assert_field("query=all:three",   selfdir + "one.result.json", "f1")
    assert_field("query=f1:one",      selfdir + "one.result.json", "f1")
    assert_field("query=f2:three",    selfdir + "one.result.json", "f1")

    assert_field("query=all:one",     selfdir + "one.result.json", "f2")
    assert_field("query=all:three",   selfdir + "one.result.json", "f2")
    assert_field("query=f1:one",      selfdir + "one.result.json", "f2")
    assert_field("query=f2:three",    selfdir + "one.result.json", "f2")

    assert_result("query=all:two",   selfdir + "two.result.json")
    assert_result("query=f1:two",    selfdir + "two.result.json")
    assert_result("query=f2:four",   selfdir + "two.result.json")
    assert_result("query=f2:four",   selfdir + "two.result.json")
    assert_result("query=all:four",  selfdir + "two.result.json")

    assert_hitcount("query=f1:three", 0)
    assert_hitcount("query=f2:one",   0)
    assert_hitcount("query=f1:four",  0)
    assert_hitcount("query=f1:four",  0)
    assert_hitcount("query=f2:two",   0)

  end

  def teardown
    stop
  end

end
