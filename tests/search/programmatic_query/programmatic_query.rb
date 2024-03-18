# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ProgrammaticQuery < IndexedSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd").
                        search_chain(SearchChain.new("federate-to-self").inherits("native").
                                       add(Federation.new("federation").add("local-vespa"))
                                    ).
                        search_chain(SearchChain.new("default").inherits("vespa").
                                       add(Federation.new("federation").add("search"))
                                    ).
                        search_chain(Provider.new("search", "local").cluster("search")).
                        search_chain(Provider.new("local-vespa", "local").cluster("search"))
                     )
    start
    feed_and_wait_for_docs("simple", 1, :file => selfdir + "feed.json")
    wait_for_hitcount("query=sddocname:simple", 1)
  end

  def test_complicated_query_can_be_sent_to_the_local_provider
    question = 'Where is the "any" key?'
    search_and_assert_one_hit("/search/?searchChain=federate-to-self&type=any&query=content:#{question}@@ Homer")
  end

  def test_accepts_programmatic_query
    query = 'type=prog&query=(WORD {"index" "content"} "Where is the \"any\" key?")'
    search_and_assert_one_hit("/search/?searchChain=search&#{query}")
    search_and_assert_one_hit("/search/?searchChain=federate-to-self&#{query}")
  end

  def search_and_assert_one_hit(query)
    result = search(query, 0, {}, :errorretries => 30)
    assert_equal(1, result.hitcount)
  end

  def teardown
    stop
  end
end
