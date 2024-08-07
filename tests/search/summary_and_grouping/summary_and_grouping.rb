# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SummaryAndGrouping < IndexedStreamingSearchTest

  def setup
    set_owner("balder")
  end

  def grouping(summary)
    return "all(group(f3) max(1) each(output(count()) each(output(summary(#{summary})))))"
  end

  def test_summary_both_flat_and_grouped
    deploy_app(SearchApp.new.sd(selfdir+'test.sd'))
    start
    feed_and_wait_for_docs("test", 1, :file => "#{selfdir}/docs.json")

    result = search("query=sddocname:test&summary=a")
    assert_equal('F1', result.hit[0].field['f1'])
    result = search("query=sddocname:test&summary=b")
    assert_equal('F2', result.hit[0].field['f2'])
    result = search("query=sddocname:test")
    assert_equal(1, result.hit[0].field['f3'])

    result = search("query=sddocname:test&select=#{grouping('a')}&summary=b")
    assert_equal(nil, result.hit[0].field['f1'])
    assert_equal('F2', result.hit[0].field['f2'])
    assert_equal(nil, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f2'])
    assert_equal('F1', result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f1'])

    result = search("query=sddocname:test&select=#{grouping('a')}")
    assert_equal(nil, result.hit[0].field['f1'])
    assert_equal(1, result.hit[0].field['f3'])
    assert_equal(nil, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f3'])
    assert_equal('F1', result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f1'])

    body_exp = "<hi>Haskell</hi> is a programming language. The programming language is <hi>haskell</hi>."
    result = search("query=body:haskell&select=#{grouping('a')}&summary=body_1")
    puts "body_1: " + result.xmldata.to_s
    assert_equal(body_exp, result.hit[0].field['body'])
    assert_equal('F1', result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f1'])

    result = search("query=body:haskell&select=#{grouping('a')}&summary=body_2")
    puts "body_2: " + result.xmldata.to_s
    assert_equal(body_exp, result.hit[0].field['body'])
    assert_equal(body_exp, result.hit[0].field['snippet'])
    assert_equal('F1', result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f1'])

    result = search("query=body:haskell&select=#{grouping('body_1')}&summary=body_2")
    puts "body_1 and body_2: " + result.xmldata.to_s
    assert_equal(body_exp, result.hit[0].field['body'])
    assert_equal(body_exp, result.hit[0].field['snippet'])
    assert_equal(body_exp, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['body'])
    assert_equal(nil, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['snippet'])

    result = search("query=body:haskell&select=#{grouping('body_2')}&summary=body_1")
    puts "body_2 and body_1: " + result.xmldata.to_s
    assert_equal(body_exp, result.hit[0].field['body'])
    assert_equal(nil, result.hit[0].field['snippet'])
    assert_equal(body_exp, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['body'])
    assert_equal(body_exp, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['snippet'])
  end

  def teardown
    stop
  end

end
