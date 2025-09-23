# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class Bug6885526Test < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end


  def test_new_line_character_preserved_with_bolding
    set_description("Test that new line character is preserved when using bolding (ticket 6885526)")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")
    assert_result("title:best", selfdir + "result.json")
  end

end
