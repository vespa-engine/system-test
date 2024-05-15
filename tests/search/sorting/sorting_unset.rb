# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class SortingUnset < IndexedStreamingSearchTest

  def setup
    set_owner('toregge')
    set_description('Test sorting when values are unset')
  end

  def test_sorting_unset_fields
    deploy_app(SearchApp.new.sd(selfdir+'unset.sd'))
    start
    feed_docs
    check_sorted(nil, [0, 1, 2, 3])
    check_sorted('-year', [3, 0, 2, 1])
    check_sorted('+year', [1, 2, 0, 3])
    check_sorted('year', [1, 2, 0, 3]) unless is_streaming
    check_sorted('-year_s', [3, 0, 2, 1])
    check_sorted('+year_s', [1, 2, 0, 3])
    check_sorted('year_s', [1, 2, 0, 3]) unless is_streaming
  end

  def feed_doc(id, year, myrank)
    doc = Document.new('unset', "id:ns:unset::#{id}")
    doc.add_field('year', year) unless year.nil?
    doc.add_field('year_s', make_string(year)) unless year.nil?
    doc.add_field('myrank', myrank)
    vespa.document_api_v1.put(doc)
  end

  def make_string(value)
    "%06d" % value
  end

  def check_sorted(sortspec, exp_ids)
    yql = 'select * from sources * where sddocname contains "unset"'
    form = [['yql', yql],
            ['hits', '10']]
    form.push(['sortspec', sortspec]) unless sortspec.nil?
    encoded_form = URI.encode_www_form(form)
    puts "encoded_form='#{encoded_form}'"
    result = search("#{encoded_form}")
    assert_hitcount(result, 4)
    puts result
    act_ids = []
    for i in 0...4
      id = result.hit[i].field['documentid'].sub(/id:ns:unset::/, '').to_i
      act_ids.push(id)
    end
    assert_equal(exp_ids, act_ids)
  end

  def feed_docs
    feed_doc(0, 2010, 8.0)
    feed_doc(1, nil, 7.0)
    feed_doc(2, 2008, 6.0)
    feed_doc(3, 2020, 5.0)
  end

  def teardown
    stop
  end
end
