# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class LuceneLinguistics < IndexedSearchTest

  def setup
    set_owner("hmusum")
    set_description("Tests that we can specify using the lucene linguistcs implementation")
  end

  def test_simple_linguistics
    deploy(selfdir + "app/")
    start
    feed_and_wait_for_docs("lucene", 1, :file => selfdir + "document.json")

    assert_hitcount("query=dog", 1)
  end

  def teardown
    stop
  end

end
