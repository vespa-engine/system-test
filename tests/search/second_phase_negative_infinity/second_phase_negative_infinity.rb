# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

require 'json'

class SecondPhaseNegativeInfinity < IndexedOnlySearchTest

  def setup
    set_owner('boeker')
  end

  def feed_and_wait
    # This should come second as it has relevance -inf in second-phase ranking
    vespa.document_api_v1.put(Document.new("id:test:test::0")
                                      .add_field("first", 10)
                                      .add_field("second", 0) # log10(0) = -inf
    )
    # This should come first as it has relevance 1 in second-phase ranking
    vespa.document_api_v1.put(Document.new("id:test:test::1")
                                      .add_field("first", 0)
                                      .add_field("second", 10) # log10(1) = 1
    )
    wait_for_hitcount('query=sddocname:test', 2)
  end

  def test_second_phase_negative_infinity
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait

    query = {'yql' => 'select * from sources * where true',
             'ranking' => 'log-rank-profile'}

    result = search(query)
    puts JSON.pretty_generate(result.json)

    assert_equal(2, result.hitcount)
    assert_equal("id:test:test::1", result.hit[0].field['documentid'])
    assert_equal(1.0, result.hit[0].field['relevancy'])
    assert_equal("id:test:test::0", result.hit[1].field['documentid'])
    assert_equal("-Infinity", result.hit[1].field['relevancy'])
  end

  def feed_and_wait_with_diversity
    # Reranked (best in group 1), relevance -inf in second-phase ranking
    vespa.document_api_v1.put(Document.new("id:test:test::0")
                                      .add_field("first", 10)
                                      .add_field("second", 0) # log10(0) = -inf
                                      .add_field("group", 1)
    )
    # Reranked (best in group 2), relevance 1 in second-phase ranking
    vespa.document_api_v1.put(Document.new("id:test:test::1")
                                      .add_field("first", 9)
                                      .add_field("second", 10) # log10(10) = 1
                                      .add_field("group", 2)
    )
    # In the first-phase heap, but not reranked as group 1 already has a reranked hit.
    # Its first-phase score is rescaled to fit below the second-phase scores, which
    # with -inf as the lowest second-phase score gives 8 * inf - inf = NaN.
    vespa.document_api_v1.put(Document.new("id:test:test::2")
                                      .add_field("first", 8)
                                      .add_field("second", 100)
                                      .add_field("group", 1)
    )
    wait_for_hitcount('query=sddocname:test', 3)
  end

  def test_second_phase_negative_infinity_with_diversity
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_with_diversity

    query = {'yql' => 'select * from sources * where true',
             'ranking' => 'log-rank-profile-diversity'}

    result = search(query)
    puts JSON.pretty_generate(result.json)

    assert_equal(3, result.hitcount)
    assert_equal("id:test:test::1", result.hit[0].field['documentid'])
    assert_equal(1.0, result.hit[0].field['relevancy'])
    assert_equal("-Infinity", result.hit[1].field['relevancy'])
    assert_equal("-Infinity", result.hit[2].field['relevancy'])

    # The container re-sorts the hits it gets by relevance (turning NaN into -inf),
    # so also check that the content node returns the right hit when it has to pick
    # which hits to return.
    result = search(query.merge('hits' => 1))
    puts JSON.pretty_generate(result.json)

    assert_equal(3, result.hitcount)
    assert_equal(1, result.hit.size)
    assert_equal("id:test:test::1", result.hit[0].field['documentid'])
    assert_equal(1.0, result.hit[0].field['relevancy'])
  end

  def feed_and_wait_with_two_threads
    # The docid range is split evenly between the two threads, so documents 0 and 1
    # are matched by the first thread and documents 2 and 3 by the second thread.

    # Reranked (top 2 in first-phase), relevance -inf in second-phase ranking
    vespa.document_api_v1.put(Document.new("id:test:test::0")
                                      .add_field("first", 10)
                                      .add_field("second", 0) # log10(0) = -inf
    )
    # Reranked (top 2 in first-phase), relevance 2 in second-phase ranking
    vespa.document_api_v1.put(Document.new("id:test:test::1")
                                      .add_field("first", 9)
                                      .add_field("second", 100) # log10(100) = 2
    )
    # In the first-phase heap of the second thread, but not reranked. Their first-phase
    # scores are rescaled to fit below the second-phase scores, which with -inf as the
    # lowest second-phase score gives 8 * inf - inf = NaN and 7 * inf - inf = NaN.
    vespa.document_api_v1.put(Document.new("id:test:test::2")
                                      .add_field("first", 8)
                                      .add_field("second", 10) # log10(10) = 1
    )
    vespa.document_api_v1.put(Document.new("id:test:test::3")
                                      .add_field("first", 7)
                                      .add_field("second", 10) # log10(10) = 1
    )
    wait_for_hitcount('query=sddocname:test', 4)
  end

  def test_second_phase_negative_infinity_with_two_threads
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_with_two_threads

    query = {'yql' => 'select * from sources * where true',
             'ranking' => 'log-rank-profile-two-threads'}

    result = search(query)
    puts JSON.pretty_generate(result.json)

    assert_equal(4, result.hitcount)
    assert_equal("id:test:test::1", result.hit[0].field['documentid'])
    assert_equal(2.0, result.hit[0].field['relevancy'])
    assert_equal("-Infinity", result.hit[1].field['relevancy'])
    assert_equal("-Infinity", result.hit[2].field['relevancy'])
    assert_equal("-Infinity", result.hit[3].field['relevancy'])

    # The container re-sorts the hits it gets by relevance (turning NaN into -inf),
    # so also check that the content node returns the right hit when it has to pick
    # which hits to return after merging the results from the two threads.
    result = search(query.merge('hits' => 1))
    puts JSON.pretty_generate(result.json)

    assert_equal(4, result.hitcount)
    assert_equal(1, result.hit.size)
    assert_equal("id:test:test::1", result.hit[0].field['documentid'])
    assert_equal(2.0, result.hit[0].field['relevancy'])
  end

end
