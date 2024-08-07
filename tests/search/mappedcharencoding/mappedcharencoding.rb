# -*- coding: utf-8 -*-
# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class MappedCharEncoding < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
    set_description("Test normalization of accents")
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
  end

  def test_mapped_char_encoding
    feed_and_wait_for_docs("test", 3, :file => selfdir+"test-documents.json")

    assert_hitcount("query=text:espana", 3)
    assert_hitcount("query=text:españa", 3)
    assert_hitcount("query=text:ESPAÑA", 3)
  end

  def teardown
    stop
  end

end
