# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class StructSummaryFieldWithExplicitSource < IndexedStreamingSearchTest
  def setup
    set_owner('toregge')
    set_description("Test struct summary field with explicit source")
    @testdir = selfdir + "struct_summary_field_with_explicit_source"
  end

  def get_app
    SearchApp.new.sd("#{@testdir}/test.sd")
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def query_string(summary)
    '/search/?' + URI.encode_www_form([['query', 'sddocname:test'],
                                       ['nocache'],
                                       ['hits', '1'],
                                       ["summary", summary ],
                                       ["format", "json" ],
                                       ['timeout', '5.0'],
                                       ['model.type', 'all'],
                                       ['streaming.selection', 'true']
                                      ])
  end

  def get_summary(summary)
    result = qrserver.search(query_string(summary))
    assert_hitcount(result, 1)
    puts "Result with #{summary} summary is"
    fields = result.json["root"]["children"][0]["fields"]
    puts JSON.pretty_generate(fields)
    puts "----"
    fields
  end

  def check_result(result, prefix)
    assert_equal('svalue0', result["#{prefix}simple"])
    assert_equal('savalue0', result["#{prefix}simple_attr"])
    assert_equal([{'value' => 'cvalue0', 'name' => 'cname0'}], result["#{prefix}complex"])
    assert_equal([{'value' => 'cavalue0', 'name' => 'caname0'}], result["#{prefix}complex_attr"])
    assert_equal('svalue2', result["#{prefix}simple3"])
    assert_equal('savalue2', result["#{prefix}simple3_attr"])
    assert_equal([{'value' => 'cvalue2', 'name' => 'cname2'}], result["#{prefix}complex3"])
    assert_equal([{'value' => 'cavalue2', 'name' => 'caname2'}], result["#{prefix}complex3_attr"])
  end

  def test_struct_summary_field_with_explicit_source
    deploy_app(get_app)
    start
    feed(:file => "#{@testdir}/docs.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:test", 1)
    basic_result = get_summary('basic')
    check_result(basic_result, '')
    rename_result = get_summary('rename')
    check_result(rename_result, 'new_')
  end

end
