# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class DynTeaserIssuesTest < IndexedStreamingSearchTest
  def setup
    set_owner("toregge")
  end

  def assert_title_in_result(yql, query, exp_title)
    form = [['query', query],
            ['yql', yql],
            ["hits", "1"],
            ["presentation.format", "json"]]
    encoded_form = URI.encode_www_form(form)
    result = search("/?#{encoded_form}")
    assert_equal(1, result.hitcount)
    hit = result.hit[0]
    act_title = hit.field['title']
    assert_equal(exp_title, act_title)
  end

  def test_additional_query_terms
    # This test is based on vespa-engine/vespa issue 26693
    set_description("Test that additional query terms works with dynamic summary")
    @testdir = selfdir + "additional_query_terms"
    deploy_app(SearchApp.new.sd(@testdir+'/test.sd'))
    start
    feed_and_wait_for_docs('test', 2, :file => @testdir+'/docs.json')
    assert_title_in_result('select * from test where (userInput(@query))', 'hamster', '<hi>Hamster</hi> one')
    assert_title_in_result('select * from test where (userInput(@query)) and true', 'hamster', '<hi>Hamster</hi> one')
    assert_title_in_result('select * from test where (!(visibility contains ("bad")) or (visibility contains ("public")) ) and ([{defaultIndex:"title"}]userInput(@query))', 'product', '<hi>product</hi> red medium')
    assert_title_in_result('select * from test where ((visibility contains ("bad")) or (visibility contains ("public")) ) and ([{defaultIndex:"title"}]userInput(@query))', 'product', '<hi>product</hi> red medium')
    assert_title_in_result('select * from test where (!(visibility contains ("bad")) ) and ([{defaultIndex:"title"}]userInput(@query))', 'product', '<hi>product</hi> red medium')
  end

  def teardown
    stop
  end
end
