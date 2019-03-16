# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class DocumentId < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Test that we get the documentid field in both default and self-defined summary class")
  end

  def test_documentid
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "feed.xml")

    assert_field_value("query=sddocname:test&streaming.selection=true", "documentid", "id:test:test::0")
    assert_field_value("query=sddocname:test&summary=s1&streaming.selection=true", "documentid", "id:test:test::0")
  end

  def teardown
    stop
  end

end
