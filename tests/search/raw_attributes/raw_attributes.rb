# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class RawAttributesTest < IndexedStreamingSearchTest

  def setup
    set_owner('toregge')
    set_description('Test raw attribute vector')
    @id_prefix = 'id:test:test::'
  end

  def test_raw_attribute
    deploy_app(SearchApp.new.sd(selfdir+'test.sd').enable_document_api)
    start
    feed_and_wait_for_docs('test', 4, :file => selfdir + 'docs.json')
    4.times do |id|
      assert_field(['dGhpcyBpcyByYXcgZGF0YQ=='], id.to_s)
    end
    assert_grouping('all(group(id) each(output(max(raw))))', selfdir + 'initial_group_by_id.json')
    assert_grouping('all(group(raw) each(output(sum(value))))', selfdir + 'initial_group_by_raw.json')
    feed(:file => selfdir + 'updates.json', :exceptiononfailure => true)
    assert_grouping('all(group(id) each(output(max(raw))))', selfdir + 'final_group_by_id.json')
    assert_grouping('all(group(raw) each(output(sum(value))))', selfdir + 'final_group_by_raw.json')
    assert_sorting('-raw +id', 'sort_by_desc_raw.json')
    assert_sorting('+raw +id', 'sort_by_asc_raw.json')
  end

  def assert_field_helper(exp_value, id, search)
    if search
      result = search(URI.encode_www_form([['query', "id:#{id}"], ['streaming.selection', 'true']]))
      assert_equal(1, result.hit.size)
      assert_equal("#{@id_prefix}#{id}", result.hit[0].field['documentid'])
      field = result.hit[0].field['raw']
    else
      hit = vespa.document_api_v1.get("#{@id_prefix}#{id}")
      field = hit.fields['raw']
    end
    assert_equal(exp_value, field)
  end

  def assert_field(exp_value, id)
    assert_field_helper(exp_value[0], id, false)
    assert_field_helper(exp_value[-1], id, true)
  end

  def assert_grouping(grouping, file)
    assert_grouping_result('/search/?' + URI.encode_www_form([['hits', '0'], ['query', 'sddocname:test'], ['select', grouping], ['streaming.selection', 'true']]), file)
  #    my_assert_query('/search/?' + URI.encode_www_form([['hits', '0'], ['yql', 'select * from test where sddocname contains "test" |' + grouping + ';'], ['streaming.selection', 'true']]), file)
  end

  def assert_same_result_sets(exp, act)
    assert_equal(exp.hitcount, act.hitcount)
    act_json = act.json
    exp_json = exp.json
    assert_equal(exp_json['root']['coverage'], act_json['root']['coverage'])
    assert_equal(exp_json['root']['children'], act_json['root']['children'])
  end

  def assert_grouping_result(query, file)
    act = search_with_timeout(5.0, query)
    exp = create_resultset(file)
    assert_same_result_sets(exp, act)
  end

  def assert_sorting(sortspec, file)
    query = "/search/?" + URI.encode_www_form([['query', 'sddocname:test'], ['sortspec', sortspec], ['streaming.selection', 'true']])
    assert_result(query, file, nil, ['id','raw', 'value', 'documentid'])
  end

  def teardown
    stop
  end
end
