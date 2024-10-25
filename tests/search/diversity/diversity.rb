# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'doc_generator'

class DiversityMinGroups < IndexedOnlySearchTest

  def setup
    set_owner('hmusum')
    @docs = 20
  end

  def test_diversity_min_groups
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
    feed_docs
    wait_for_hitcount("query=sddocname:music", @docs)

    # All docs match this query, but 1 doc has higher relevancy, see feed_docs()
    puts "Query: 'rock'"
    @expected_relevancy_best_doc = 1000.3818623835995
    @expected_relevancy_rest = 1000.16343879032
    @expected_relevancy_no_second_phase = 0.16343879032006287

    assert_hitcount("query=rock", @docs)
    assert_relevancy("query=rock&ranking=base", @expected_relevancy_best_doc, 0)
    assert_relevancy("query=rock&ranking=diversity_min_groups_5", @expected_relevancy_best_doc, 0)
    # Should get 1 hit that is doc 0, rest should have gone through second phase
    # TODO: Fails with @docs = 20, works with @docs = 50
    check_relevancy("query=rock&ranking=diversity_min_groups_5", @expected_relevancy_rest, {0 => @expected_relevancy_best_doc})
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

  def check_relevancy(query, default_relevance, hit_number_to_relevance_mapping, hits=10)
    result = search(query)
    assert_equal(hits, result.hit.length)
    hits.times.each { |i|
      puts "hit #{i} relevance = #{relevance(result, i)}"
    }
    puts "---\n"
    hits.times.each { |i|
      expected_relevance = hit_number_to_relevance_mapping[i]
      expected_relevance = default_relevance unless expected_relevance
      hit = result.hit[i]
      relevance = relevance(result, i)
      assert_approx(expected_relevance, relevance, 0.01, "expected: #{expected_relevance}, got #{relevance} for hit #{i}: #{hit}")
    }
  end

  def relevance(result, index)
    result.hit[index].field['relevancy'].to_f
  end

  def teardown
    stop
  end

end

