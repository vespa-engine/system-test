# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class SortingMultiValue < IndexedStreamingSearchTest

  def setup
    set_owner('toregge')
    set_description('Test sorting on multivalue attributes')
  end

  def test_sorting_multivalue_fields
    deploy_app(SearchApp.new.sd(selfdir+'multivalue.sd'))
    start
    feed_docs
    check_sorted(nil, [0, 1, 2, 3])
    check_sorted_multi('-years', [2, 3, 0, 1])
    check_sorted_multi('+years', [2, 0, 3, 1])
    check_sorted_multi2_string('-missing(years,first)', [1, 2, 3, 0])
    check_sorted_multi2('+missing(years,first)', [1, 2, 0, 3])
    check_sorted_multi2('-missing(years,last)', [2, 3, 0, 1])
    check_sorted_multi2('+missing(years,last)', [2, 0, 3, 1])
    check_sorted_multi2_string('-missing(years,as,2017)', [2, 3, 1, 0])
    check_sorted_multi2_string('+missing(years,as,2017)', [2, 0, 1, 3])
    check_sorted_multi2_string('-missing(years,as,2009)', [2, 3, 0, 1])
    check_sorted_multi2_string('+missing(years,as,2009)', [2, 1, 0, 3])
    check_sorted_multi2_string('-missing(years,as,2022)', [1, 2, 3, 0])
    check_sorted_multi2_string('+missing(years,as,2022)', [2, 0, 3, 1])
  end

  def make_strings(array)
    return nil if array.nil?
    result = []
    for key in array
      result.push("%06d" % key)
    end
  end

  def make_wset(array)
    return nil if array.nil?
    wset = {}
    for key in array
      wset[key] = 1
    end
    wset
  end

  def feed_doc(id, years, myrank)
    doc = Document.new('multivalue', "id:ns:multivalue::#{id}")
    years_wset = make_wset(years)
    years_s = make_strings(years)
    years_s_wset = make_wset(years_s)
    doc.add_field('years', years) unless years.nil?
    doc.add_field('years_fs', years) unless years.nil?
    doc.add_field('years_wset', years_wset) unless years_wset.nil?
    doc.add_field('years_wset_fs', years_wset) unless years_wset.nil?
    doc.add_field('years_s', years_s) unless years_s.nil?
    doc.add_field('years_s_wset', years_s_wset) unless years_s_wset.nil?
    doc.add_field('myrank', myrank)
    vespa.document_api_v1.put(doc)
  end

  def check_sorted_multi(sortspec, exp_ids)
    for suffix in ['', '_fs', '_wset', '_wset_fs', '_s', '_s_wset']
      check_sorted(sortspec + suffix, exp_ids)
    end
  end

  def check_sorted_multi2(sortspec, exp_ids)
    for sub in [',', '_fs,', '_wset,', '_wset_fs,', '_s,', '_s_wset,']
      mangled_sortspec = sortspec.gsub(',',sub)
      puts "mangled_sortspec is #{mangled_sortspec}"
      check_sorted(mangled_sortspec, exp_ids)
    end
  end

  def check_sorted_multi2_string(sortspec, exp_ids)
    for sub in ['_s,', '_s_wset,']
      mangled_sortspec = sortspec.gsub(',',sub)
      puts "mangled_sortspec is #{mangled_sortspec}"
      check_sorted(mangled_sortspec, exp_ids)
    end
  end

  def check_sorted(sortspec, exp_ids)
    yql = 'select * from sources * where true'
    form = [['yql', yql]]
    form.push(['sortspec', sortspec]) unless sortspec.nil?
    form.push(['trace.level', '9'])
    form.push(['trace.explainLevel', '9'])
    encoded_form = URI.encode_www_form(form)
    puts "encoded_form='#{encoded_form}'"
    result = search("#{encoded_form}")
    assert_hitcount(result, 4)
    puts result
    act_ids = []
    for i in 0...4
      id = result.hit[i].field['documentid'].sub(/id:ns:multivalue::/, '').to_i
      act_ids.push(id)
    end
    assert_equal(exp_ids, act_ids)
  end

  def feed_docs
    feed_doc(0, [2010], 8.0)
    feed_doc(1, nil, 7.0)
    feed_doc(2, [2021, 2005], 6.0)
    feed_doc(3, [2020], 5.0)
  end

  def teardown
    stop
  end
end
