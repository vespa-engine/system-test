# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class ImplitictIndexPhrase < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Check implicit phrasing when querying for non-existant index.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_implicitindexphrase
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json")

    puts "Query: Querying, checking implicit phrase"
    result = search("query=notanindex:blues&tracelevel=1")
    assert(result.xmldata.include?("query=[WEAKAND (AND notanindex blues)]"),
           "Result does not contain string:query=[WEAKAND (AND notanindex blue)]")
    puts "Query: Querying, checking specific index"
    result = search("query=title:nosuchtitle&tracelevel=1")
    assert(result.xmldata.include?("query=[WEAKAND title:nosuchtitle]"),
           "Result does not contain string:query=[WEAKAND title:nosuchtitle]")
  end


end
