# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class IndexingNow < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_indexing_now
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start
    feed_and_wait_for_docs("simple", 1, :file => "#{selfdir}/doc.json")
    result_file = "#{dirs.tmpdir}/result.json"
    save_result("/?query=sddocname:simple", result_file)
    sleep(1) # need time to change
    feedfile("#{selfdir}/upd.json")
    assert_result("/?query=sddocname:simple", result_file)
  end


end
