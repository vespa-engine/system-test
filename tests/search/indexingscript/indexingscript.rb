# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class IndexingScript < IndexedStreamingSearchTest

  def setup
    set_owner("yngve")
    set_description("Test that complex indexing scripts work as expected.")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start
  end

  def test_indexingscript_types
    feed_and_wait_for_docs("test", 10, :file => "#{selfdir}/input.json")
    assert_result("query=sddocname:test", "#{selfdir}/result.json", "a")
  end

  def teardown
    stop
  end

end
