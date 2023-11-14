# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class DupRemove < IndexedSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.
                         container(Container.new.
                                             search(Searching.new).
                                             config(ConfigOverride.new("container.qr-searchers").
                                                                   add("com", ConfigValue.new("yahoo", ConfigValue.new("prelude", ConfigValue.new("searcher", ConfigValue.new("BlendingSearcher", ConfigValue.new("docid", "marker")))))))).
                         cluster(SearchCluster.new("simple1").
                                               sd(selfdir+"simple.sd")).
                         cluster(SearchCluster.new("simple2").
                                               sd(selfdir+"simple.sd")))
    start
    feed_and_wait_for_docs("simple", 6, :file => selfdir + "simple.3.xml", :clusters => ["simple1", "simple2"])
  end

  def test_blendingdupremove
    result =  search("/?query=marker:all&hits=20")
    assert(result.hitcount == 6, "Expected 6 hits in total, got #{result.hitcount}")
    assert(result.hit.size == 3, "Expected 3 hits returned, got #{result.hit.size}")
  end

  def teardown
    stop
  end

end
