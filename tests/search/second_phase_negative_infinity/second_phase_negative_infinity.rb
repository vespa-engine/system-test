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

end
