# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'doc_generator'

class DiversityMinGroups < IndexedOnlySearchTest

  def setup
    set_owner('hmusum')
    @docs = 50
    @expected_relevancy = 1000.3344587750165
  end

  def test_diversity_min_groups
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
    feed_docs
    wait_for_hitcount("query=sddocname:music", @docs)
    # All docs match this query, but 1 doc has lower relevancy, see feed_docs()
    assert_hitcount("query=cherub+rock", @docs)
    assert_hitcount("query=cherub+rock&ranking=base", @docs)

    assert_relevancy("query=cherub+rock&ranking=base", @expected_relevancy, 0)
    assert_relevancy("query=cherub+rock&ranking=diversity", @expected_relevancy, 0)
    # diversity.min-groups is 60 in the 'diversity_many_groups' rank profile, more than number of docs
    # => not aenough docs to fulfill min-groups criteria
    assert_relevancy("query=cherub+rock&ranking=diversity_many_groups", @expected_relevancy, 0)
  end

  def feed_docs
    @docs.times.each { |i|
      doc = Document.new('music', "id:test:music::#{i}")
      if i == 0
        doc.add_field('genre', 'rock')
        doc.add_field('artist', 'The Clash')
        doc.add_field('title', 'Rock the Casbah')
      else
        doc.add_field('genre', 'alternative')
        doc.add_field('artist', 'Smashing Pumpkins')
        doc.add_field('title', 'Cherub Rock')
      end
      vespa.document_api_v1.put(doc, :brief => true)
    }
  end

  def teardown
    stop
  end

end

