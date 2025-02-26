# coding: utf-8
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

  def test_casing_and_accents
    # Test that exact match is highlighted with various combinations of case and accent normalization
    deploy_app(SearchApp.new.sd(selfdir + 'simple.sd'))
    start
    feed_and_wait_for_docs('simple', 1, :file => selfdir+'simple.doc.json')
    vespa.adminserver.logctl('searchnode:juniper', 'all=on')
    lower_words = 'blå bær muß für søster sœur elise'
    upper_words = 'Blå Bær Muß Für Søster Sœur Elise'
    wanted = '<hi>blå</hi> <hi>bær</hi> <hi>muß</hi> <hi>für</hi> <hi>søster</hi> <hi>sœur</hi> <hi>elise</hi>; ' +
             '<hi>Blå</hi> <hi>Bær</hi> <hi>Muß</hi> <hi>Für</hi> <hi>Søster</hi> <hi>Sœur</hi> <hi>Elise</hi>'
    assert_equal(wanted, get_field_from_words("normal", lower_words))
    assert_equal(wanted, get_field_from_words("normal", upper_words))
    assert_equal(wanted, get_field_from_words("nonorm", lower_words))
    assert_equal(wanted, get_field_from_words("nonorm", upper_words))
  end

  def get_field_from_words(fieldname, words)
    qwords = ERB::Util.url_encode(words)
    query = "/?query=#{qwords}&type=any&default-index=#{fieldname}"
    result = search(query)
    if result.hit[0]
      ret = result.hit[0].field[fieldname]
      puts "Search #{words} -> #{ret}"
      return ret
    else
      puts("BAD result: #{result}")
      puts result.json
      raise "bad result"
    end
  end

  def teardown
    stop
  end
end
