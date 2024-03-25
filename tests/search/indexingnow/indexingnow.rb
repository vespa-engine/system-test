# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class IndexingNow < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_indexing_now
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start
    feed_and_wait_for_docs("simple", 1, :file => "#{selfdir}/doc.json")
    save_result("/?query=sddocname:simple", "result.xml")
    sleep(1) # need time to change
    feedfile("#{selfdir}/upd.json")
    assert_result("/?query=sddocname:simple", "result.xml");
  end

  def teardown
    stop
  end

end
