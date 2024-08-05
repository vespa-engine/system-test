# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class DirectSearch < IndexedOnlySearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that we dispatch to just the local node when is it has the entire corpus")
  end

  def test_directsearch
    deploy_app(SearchApp.new.sd(selfdir + "music.sd"))
    start
    feed_and_wait_for_docs("music", 777, :file => selfdir + "../data/music.777.json")

    directquery='query=best%20albert&presentation.format=xml&type=all'

    # verfify that we use direct dispatch since this is a single-node system
    assert(search(directquery + "&tracelevel=2").xmldata.include?("Dispatching to search node"), "Dispatching to local node")

    # verfify that the result contains all the usual information
    assert_result(directquery, selfdir + "expected.result")
   end

  def teardown
    stop
  end

end
