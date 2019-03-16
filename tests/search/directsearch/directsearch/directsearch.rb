# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class DirectSearch < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that we bypass dispatch when the local search node has the entire corpus")
  end

  def test_directsearch
    deploy_app(SearchApp.new.sd(selfdir + "music.sd"))
    start
    feed_and_wait_for_docs("music", 777, :file => selfdir + "../data/music.777.xml")

    directquery="query=best%20albert&presentation.format=xml&dispatch.direct=true&nocache"

    # verfify that we use direct dispatch since this is a single-node system
    assert(search(directquery + "&tracelevel=2").xmldata.include?("Dispatching directly"), "We use direct search")

    # verfify that the result contains all the usual information
    assert_result(directquery, selfdir + "expected.result")
   end

  def teardown
    stop
  end

end
