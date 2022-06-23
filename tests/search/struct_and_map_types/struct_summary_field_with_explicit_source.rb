# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'

class StructSummaryFieldWithExplicitSource < SearchTest
  def setup
    set_owner('toregge')
    set_description("Test struct summary field with explicit source")
    @testdir = selfdir + "struct_summary_field_with_explicit_source"
  end

  def get_app
    sc = SearchCluster.new('test')
    sc.sd("#{@testdir}/test.sd")
    app = SearchApp.new.cluster(sc)
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
                                      ])
  end

  def get_summary(summary)
    result = qrserver.search(query_string(summary))
    assert(1, result.hitcount)
    puts "Result with #{summary} summary is"
    puts JSON.pretty_generate(result.json["root"]["children"][0]["fields"])
    puts "----"
  end

  def test_struct_summary_field_with_explicit_source
    deploy_app(get_app)
    start
    feed(:file => "#{@testdir}/docs.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:test", 1)
    basic_result = get_summary('basic')
    rename_result = get_summary('rename')
  end

  def teardown
    stop
  end
end
