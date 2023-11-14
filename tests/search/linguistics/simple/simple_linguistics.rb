# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SimpleLinguistics < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that we can specify using the simple linguistcs implementation")
  end

  def test_simple_linguistics
    deploy(selfdir + "app/")
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "documents.xml")

    # simple linguistics (kstem) does not stem 'run' and 'running' to the same stem
    assert_hitcount("query=text:run", 1)
    assert_hitcount("query=text:running", 1)
   end

  def teardown
    stop
  end

end
