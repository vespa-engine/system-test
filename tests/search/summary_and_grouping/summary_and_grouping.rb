# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class SummaryAndGrouping < IndexedStreamingSearchTest

  def setup
    set_owner("balder")
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

    grouping = "all(group(f3) max(1) each(output(count()) each(output(summary(a)))))"
    result = search("query=sddocname:test&select=#{grouping}&summary=b")
    assert_equal(nil, result.hit[0].field['f1'])
    assert_equal('F2', result.hit[0].field['f2'])
    assert_equal(nil, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f2'])
    assert_equal('F1', result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f1'])

    result = search("query=sddocname:test&select=#{grouping}")
    assert_equal(nil, result.hit[0].field['f1'])
    assert_equal(1, result.hit[0].field['f3'])
    assert_equal(nil, result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f3'])
    assert_equal('F1', result.groupings['group:root:0']['children'][0]['children'][0]['children'][0]['children'][0]['fields']['f1'])
  end

  def teardown
    stop
  end

end
