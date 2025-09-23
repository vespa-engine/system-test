# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SelectJsonQuery < IndexedStreamingSearchTest

  def setup
    set_owner("boeker")
    set_description("Test that we can POST Json payload with a 'select' query")
    deploy_app(SearchApp.new.sd(selfdir + "music.sd"))
    start
  end

  def feed_doc(id, doc_template)
    doc = Document.new("id:test:music::#{id}}").
      add_field("title", doc_template[:title]).
      add_field("artist", doc_template[:artist]).
      add_field("year", doc_template[:year])
    vespa.document_api_v1.put(doc)
  end

  def test_search
    start

    feed_doc(0, { :title => "Blues" })
    feed_doc(1, { :title => "Country Blues" })

    assert_hits(1, "'select': { 'where': { 'contains': ['default', 'country'] } }")
  end

  def test_in
    start

    feed_doc(0, { :title => "Last Night in Hamburg",
                  :artist => "The Beatles",
                  :year => "1999" })

    feed_doc(1, { :title => "Try This [Clean] [Bonus DVD]",
                  :artist => "Pink",
                  :year => "2003" })

    feed_doc(2, { :title => "Endless Pain (Remastered)",
                  :artist => "Kreator",
                  :year => "2001" })

    assert_hits(1,"'select': { 'where': { 'in': ['year', 1999] } }")
    assert_hits(1,"'select': { 'where': { 'in': ['year', 2001] } }")
    assert_hits(1, "'select': { 'where': { 'in': ['year', 2003] } }")
    assert_hits(2, "'select': { 'where': { 'in': ['year', 1999, 2001] } }")
    assert_hits(2, "'select': { 'where': { 'in': ['year', 1999, 2003] } }")
    assert_hits(2, "'select': { 'where': { 'in': ['year', 2001, 2003] } }")
    assert_hits(3, "'select': { 'where': { 'in': ['year', 1999, 2001, 2003] } }")

    assert_hits(1, "'select': { 'where': { 'in': ['artist', 'Pink'] } }")
    assert_hits(1, "'select': { 'where': { 'in': ['artist', 'The Beatles'] } }")
    assert_hits(1, "'select': { 'where': { 'in': ['artist', 'Kreator'] } }")
    assert_hits(2, "'select': { 'where': { 'in': ['artist', 'Pink', 'The Beatles'] } }")
    assert_hits(2, "'select': { 'where': { 'in': ['artist', 'Pink', 'Kreator'] } }")
    assert_hits(2, "'select': { 'where': { 'in': ['artist', 'The Beatles', 'Kreator'] } }")
    assert_hits(3, "'select': { 'where': { 'in': ['artist', 'Pink', 'The Beatles', 'Kreator'] } }")
  end

  def assert_hits(expected_hits, query)
    result = post_query(query)
    assert_equal(expected_hits, result.hit.length)
  end

  def post_query(query)
    vespa.container.values.first.post_search("/search/", "{ " + query + ", 'streaming.selection': 'true', 'timeout': 5 }", 0, {'Content-Type' => 'application/json'})
  end


end
