# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class NestedPhrases < IndexedStreamingSearchTest

  def setup
    set_owner('boeker')
  end

  def test_unsegmented_phrase
    set_description('Search using YQL query with phrase function with unsegmented arguments.')
    deploy_app(SearchApp.new.sd(SEARCH_DATA+'music.sd'))
    start

    vespa.document_api_v1.put(Document.new("id:test:music::0").add_field("artist", "one - two-three four"))
    wait_for_hitcount("?query=sddocname:music", 1)

    assert_phrase("\"one\",\"two\",\"three\",\"four\"")
    assert_phrase("\"one-two\",\"three\",\"four\"")
    assert_phrase("\"one\",\"two-three\",\"four\"")
    assert_phrase("\"one\",\"two\",\"three-four\"")
    assert_phrase("\"one-two-three\",\"four\"")
    assert_phrase("\"one\",\"two-three-four\"")
    assert_phrase("\"one-two-three-four\"")
  end

  def assert_phrase(args)
    puts "phrase(#{args})"
    assert_hitcount("yql=select * from sources * where artist contains phrase(#{args})", 1)
  end


end
