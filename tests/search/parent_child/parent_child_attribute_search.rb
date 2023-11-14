# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ParentChildAttributeSearchTest < IndexedSearchTest

  def setup
    set_owner('vekterli')
  end

  def deploy_and_start(subdir)
    deploy_app(SearchApp.new.sd("#{selfdir}/#{subdir}/campaign.sd", { :global => true }).sd("#{selfdir}/#{subdir}/ad.sd"))
    start
  end

  def feed_baseline(subdir)
    feed_and_wait_for_docs('campaign', 2, :file => "#{selfdir}/#{subdir}/campaign-docs.json")
    feed_and_wait_for_docs('ad', 5, :file => "#{selfdir}/#{subdir}/ad-docs.json")
  end

  def convert_relevancy(relevancy)
    relevancy == '-Infinity' ? -Float::INFINITY : relevancy.to_i
  end

  def build_hit_relevancy_map(results)
    # Quantize the floating point relevancy scores to make testing more straight forward
    results.hit.map{|h| [h.field['documentid'], convert_relevancy(h.field['relevancy'])]}.to_h
  end

  def check_rankings(expected)
    result = search('query=sddocname:ad&presentation.format=json')
    relevancies = build_hit_relevancy_map(result)
    assert_equal(expected, relevancies)
  end

  def parent_not_found(ad_score)
    -Float::INFINITY
  end

  def empty_budget_ref(ad_score)
    parent_not_found(ad_score)
  end

  def no_budget_ref(ad_score)
    parent_not_found(ad_score)
  end

  def budget_and_score(campaign_budget, ad_score)
    # Super simple linear ranking function matching that of ad.sd's first-phase expression
    campaign_budget + ad_score
  end

  def feed_json(subdir, file)
    feed(:file => "#{selfdir}/#{subdir}/#{file}")
  end

  def test_single_parent_attribute_can_be_used_in_ranking_expressions
    set_description('Test that a single parent attribute can be used in ranking expressions, ' +
                    'and that updates to referenced documents implicitly affect the ranking')
    subdir = 'single_parent_attribute'
    deploy_and_start(subdir)

    feed_baseline(subdir)
    # Must be kept in sync with ad-docs.json and campaign-docs.json
    check_rankings({'id:test:ad::1' => budget_and_score(20, 1),
                    'id:test:ad::2' => budget_and_score(10, 2),
                    'id:test:ad::3' => parent_not_found(3),
                    'id:test:ad::4' => empty_budget_ref(4),
                    'id:test:ad::5' => no_budget_ref(5)
    })

    feed_json(subdir, 'ad-update-parent-refs.json')
    check_rankings({'id:test:ad::1' => no_budget_ref(1),
                    'id:test:ad::2' => empty_budget_ref(2),
                    'id:test:ad::3' => budget_and_score(20, 3),
                    'id:test:ad::4' => budget_and_score(10, 4),
                    'id:test:ad::5' => parent_not_found(5)
    })

    feed_json(subdir, 'campaign-update-budgets.json') # transitively affects ads 3 and 4
    expected = {'id:test:ad::1' => no_budget_ref(1),
                'id:test:ad::2' => empty_budget_ref(2),
                'id:test:ad::3' => budget_and_score(50, 3),
                'id:test:ad::4' => budget_and_score(30, 4),
                'id:test:ad::5' => parent_not_found(5)
    }
    check_rankings(expected)

    feed_json(subdir, 'campaign-add-single-missing.json')
    expected['id:test:ad::5'] = budget_and_score(10, 5) # parent was added
    check_rankings(expected)

    feed_json(subdir, 'campaign-remove-single.json')
    expected['id:test:ad::5'] = parent_not_found(5) # ... and it's gone again
    check_rankings(expected)
  end

  def check_hits_relevancy(query, expected)
    result = search("query=#{query}&presentation.format=json")
    relevancies = build_hit_relevancy_map(result)
    assert_equal(expected, relevancies)
  end

  def test_single_value_parent_attribute_is_searchable_via_child
    set_description('Test that a single-valued parent attribute can be used in searches, ' +
                    'and that updates to referenced documents implicitly affect search results')
    subdir = 'single_parent_attribute'
    deploy_and_start(subdir)

    feed_baseline(subdir)
    check_hits_relevancy('my_budget:20', {'id:test:ad::1' => budget_and_score(20, 1)})
    check_hits_relevancy('my_budget:10', {'id:test:ad::2' => budget_and_score(10, 2)})
    check_hits_relevancy('my_budget:>0', {'id:test:ad::1' => budget_and_score(20, 1),
                                          'id:test:ad::2' => budget_and_score(10, 2)})
    check_hits_relevancy('my_title:thebest',  {'id:test:ad::1' => budget_and_score(20, 1)})
    check_hits_relevancy('my_title:nextbest', {'id:test:ad::2' => budget_and_score(10, 2)})
    check_hits_relevancy('my_title:nothere',  {})

    feed_json(subdir, 'ad-update-parent-refs.json')
    check_hits_relevancy('my_budget:>0', {'id:test:ad::3' => budget_and_score(20, 3),
                                          'id:test:ad::4' => budget_and_score(10, 4)})
    check_hits_relevancy('my_title:thebest',  {'id:test:ad::3' => budget_and_score(20, 3)})
    check_hits_relevancy('my_title:nextbest', {'id:test:ad::4' => budget_and_score(10, 4)})
    check_hits_relevancy('my_title:nothere',  {})

    feed_json(subdir, 'campaign-update-budgets.json') # transitively affects ads 3 and 4
    check_hits_relevancy('my_budget:50', {'id:test:ad::3' => budget_and_score(50, 3)})
    check_hits_relevancy('my_budget:30', {'id:test:ad::4' => budget_and_score(30, 4)})
    check_hits_relevancy('my_budget:>0', {'id:test:ad::3' => budget_and_score(50, 3),
                                          'id:test:ad::4' => budget_and_score(30, 4)})

    feed_json(subdir, 'campaign-add-single-missing.json')
    check_hits_relevancy('my_budget:>0', {'id:test:ad::3' => budget_and_score(50, 3),
                                          'id:test:ad::4' => budget_and_score(30, 4),
                                          'id:test:ad::5' => budget_and_score(10, 5)})
    check_hits_relevancy('my_title:thebest',  {'id:test:ad::3' => budget_and_score(50, 3)})
    check_hits_relevancy('my_title:nextbest', {'id:test:ad::4' => budget_and_score(30, 4)})
    check_hits_relevancy('my_title:nothere',  {'id:test:ad::5' => budget_and_score(10, 5)})

    feed_json(subdir, 'campaign-remove-single.json')
    check_hits_relevancy('my_budget:>0', {'id:test:ad::3' => budget_and_score(50, 3),
                                          'id:test:ad::4' => budget_and_score(30, 4)})
  end

  def test_reference_attribute_is_searchable
    set_description("Test that the reference attribute in the child (ad) can be searched using parent document id")
    set_owner("geirst")
    subdir = "single_parent_attribute"
    deploy_and_start(subdir)
    feed_baseline(subdir)

    assert_reference_search("id:test:campaign::the-best", ["id:test:ad::1"])
    assert_reference_search("id:test:campaign::nothing", [])
    assert_reference_search("invalid document id", [])
  end

  def assert_reference_search(parent_doc_id, exp_children)
    result = search("query=campaign_ref:\"#{parent_doc_id}\"&presentation.format=json")
    assert_hitcount(result, exp_children.size)
    for i in 0...exp_children.size do
      assert_equal(exp_children[i], result.hit[i].field['documentid'])
    end
  end

  def check_hits_summary(query, expected_hits)
    results = search("query=#{query}&presentation.format=json&summary=my_summary")
    actual_hits = results.hit.map{|h| [h.field['documentid'], [h.field['my_title'], h.field['my_budget']]]}.to_h
    assert_equal(expected_hits, actual_hits)
  end

  def test_document_summary_containing_imported_fields
    set_description('Test that a document summary with a summary field using an imported field as source is ' +
                        'correctly containing the value of the parent document')
    subdir = 'single_parent_attribute'
    deploy_and_start(subdir)
    feed_baseline(subdir)
    expected_hits = {
        'id:test:ad::1' => ["thebest", 20],
        'id:test:ad::2' => ["nextbest", 10],
        'id:test:ad::3' => [nil, nil],
        'id:test:ad::4' => [nil, nil],
        'id:test:ad::5' => [nil, nil]
    }
    check_hits_summary('sddocname:ad', expected_hits)
  end


  def teardown
    stop
  end

end
