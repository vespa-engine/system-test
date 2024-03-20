# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class DocumentId < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Test that we get the documentid field in both default and self-defined summary class")
  end

  def test_documentid
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "feed.json")

    result = search('query=sddocname:test')
    assert_equal(1, result.hitcount)
    assert_equal('id:test:test::0', result.hit[0].field['documentid'])
    result = search('query=sddocname:test&summary=s1')
    assert_equal(1, result.hitcount)
    assert_equal('id:test:test::0', result.hit[0].field['documentid'])
  end

  def teardown
    stop
  end

end
