# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class LongWords < IndexedSearchTest
  # Description: Search for very long words
  # Component: Search
  # Feature: Query functionality
  # $Id$

  def setup
    set_owner("yngve")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    start
  end

  def test_longwords

    feed_and_wait_for_docs("simple", 99, :file => selfdir + "longwords.input.xml")

    str = "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUV"

    assert_hitcount("query=" + str, 0)

    for i in 1..99 do
      substr =  str[0,i]
      #  puts substr
      assert_hitcount("query=" + substr, 1)
    end
  end

  def teardown
    stop
  end
end
