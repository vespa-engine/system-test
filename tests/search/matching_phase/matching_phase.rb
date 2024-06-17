# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class MatchingPhase < IndexedOnlySearchTest

  def setup
    set_owner('toregge')
  end

  def test_matching_phase
    set_description("Test that hits from first phase are still considered hits in later matching phases")
    deploy_app(SearchApp.new.sd(selfdir+'test.sd').threads_per_search(1))
    start
    feed_docs
    run_weak_and_query(5)
    run_weak_and_query(1)
    run_nns_query(5)
    run_nns_query(1)
  end

  def run_weak_and_query(target_hits)
    # significance used for bm25, weight used for weak and
    wand_terms = [ 'text contains ({significance:0.1, weight:100}"one")',
                    'text contains ({significance:0.2, weight:200}"two")',
                    'text contains ({significance:0.3, weight:300}"three")',
                    'text contains ({significance:0.5, weight:500}"four")',
                    'text contains ({significance:0.4, weight:400}"five")' ];
    result = search({ 'yql' => 'select * from sources * where ({targetHits: ' + target_hits.to_s + '}weakAnd(' + wand_terms.join(', ') + '))',
                    'ranking' => 'weakand'})
    if target_hits == 1
      # First update of scores heap limit is after 4 documents.
      # DEFAULT_PARALLEL_WAND_SCORES_ADJUST_FREQUENCY = 4
      # constant defined in searchlib/queryeval/wand/wand_parts.h
      assert_hitcount(result, 4)
      assert_equal(['id:test:test::4', 'id:test:test::3', 'id:test:test::2', 'id:test:test::1'], result.get_field_array('documentid'))
      assert_equal([0.5, 0.3, 0.2, 0.1], result.get_field_array('relevancy'))
    else
      assert_hitcount(result, 5)
      assert_equal(['id:test:test::4', 'id:test:test::5', 'id:test:test::3', 'id:test:test::2', 'id:test:test::1'], result.get_field_array('documentid'))
      assert_equal([0.5, 0.4, 0.3, 0.2, 0.1], result.get_field_array('relevancy'))
    end
  end

  def calc_exp_nns_relevancy(distances)
    res = []
    for distance in distances
      res.push(100.0 - distance)
    end
    res
  end

  def calc_exp_nns_rawscores(distances)
    res = []
    for distance in distances
      res.push(1.0 / (1.0 + distance))
    end
    res
  end

  def extract_features(result, field, feature)
    features = []
    result.hit.each do |h|
      features.push(h.field[field][feature])
    end
    features
  end

  def run_nns_query(target_hits)
    result = search({ 'yql' => 'select * from sources * where ({targetHits: ' + target_hits.to_s + ', label: "nns"}nearestNeighbor(pos, query_pos))',
                      'input.query(query_pos)' => '[0.0,0.0]',
                      'ranking' => 'nns'})
    if target_hits == 1
      # First four documents are considered hits by first phase due to them
      # getting closer to origo
      assert_hitcount(result, 4)
      assert_equal(['id:test:test::4', 'id:test:test::3', 'id:test:test::2', 'id:test:test::1'], result.get_field_array('documentid'))
      exp_distances = [ 5.0, 15.0, 20.0, 25.0 ]
      exp_relevancy = calc_exp_nns_relevancy(exp_distances)
      assert_equal(exp_relevancy, result.get_field_array('relevancy'))
      exp_rawscores = calc_exp_nns_rawscores(exp_distances)
      assert_equal(exp_rawscores, extract_features(result, 'matchfeatures', 'itemRawScore(nns)'))
    else
      assert_hitcount(result, 5)
      assert_equal(['id:test:test::4', 'id:test:test::5', 'id:test:test::3', 'id:test:test::2', 'id:test:test::1'], result.get_field_array('documentid'))
      exp_distances = [ 5.0, 10.0, 15.0, 20.0, 25.0 ]
      exp_relevancy = calc_exp_nns_relevancy(exp_distances)
      assert_equal(exp_relevancy, result.get_field_array('relevancy'))
      exp_rawscores = calc_exp_nns_rawscores(exp_distances)
      assert_equal(exp_rawscores, extract_features(result, 'matchfeatures', 'itemRawScore(nns)'))
    end
  end

  def feed_doc(id, text, pos)
    doc = Document.new('test', id).add_field('text', text).add_field('pos', { 'values' => pos })
    vespa.document_api_v1.put(doc)
  end

  def feed_docs
    feed_doc('id:test:test::1', 'one', [ 15.0, 20.0 ])
    feed_doc('id:test:test::2', 'two', [ 12.0, 16.0 ])
    feed_doc('id:test:test::3', 'three', [ 9.0, 12.0 ])
    feed_doc('id:test:test::4', 'four', [ 3.0, 4.0 ])
    feed_doc('id:test:test::5', 'five', [ 6.0, 8.0 ])
    wait_for_hitcount({ 'query' => 'sddocname:test' }, 5)
  end

  def teardown
    stop
  end

end
