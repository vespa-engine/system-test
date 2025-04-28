# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class SortingMissing < IndexedStreamingSearchTest

  def setup
    set_owner('toregge')
    set_description('Test sorting with missing policy')
  end

  def test_sorting_missing_fields
    deploy_app(SearchApp.new.sd(selfdir+'missing.sd'))
    start
    feed_docs
    check_sorted(nil, [0, 1, 2, 3])
    check_sorted_multi('-years', [2, 3, 0, 1])
    check_sorted_multi('+years', [2, 0, 3, 1])
    check_sorted_multi('-missing(years,first)', [1, 2, 3, 0])
    check_sorted_multi('+missing(years,first)', [1, 2, 0, 3])
    check_sorted_multi('-missing(years,last)', [2, 3, 0, 1])
    check_sorted_multi('+missing(years,last)', [2, 0, 3, 1])
    check_sorted_multi('-missing(years,as,2017)', [2, 3, 1, 0])
    check_sorted_multi('+missing(years,as,2017)', [2, 0, 1, 3])
    check_sorted_multi('-missing(years,as,2009)', [2, 3, 0, 1])
    check_sorted_multi('+missing(years,as,2009)', [2, 1, 0, 3])
    check_sorted_multi('-missing(years,as,2022)', [1, 2, 3, 0])
    check_sorted_multi('+missing(years,as,2022)', [2, 0, 3, 1])
    check_sorted_error('+missing(years,as,invalid)')
    check_sorted_single('-year', [2, 3, 0, 1])
    check_sorted_single('+year', [1, 0, 3, 2])
    check_sorted_single('-missing(year,first)', [1, 2, 3, 0])
    check_sorted_single('+missing(year,first)', [1, 0, 3, 2])
    check_sorted_single('-missing(year,last)', [2, 3, 0, 1])
    check_sorted_single('+missing(year,last)', [0, 3, 2, 1])
    check_sorted_single('-missing(year,as,2017)', [2, 3, 1, 0])
    check_sorted_single('+missing(year,as,2017)', [0, 1, 3, 2])
    check_sorted_single('-missing(year,as,2009)', [2, 3, 0, 1])
    check_sorted_single('+missing(year,as,2009)', [1, 0, 3, 2])
    check_sorted_single('-missing(year,as,2022)', [1, 2, 3, 0])
    check_sorted_single('+missing(year,as,2022)', [0, 3, 2, 1])
    check_sorted_error('+missing(year,as,invalid)')
  end

  def make_string(key)
    return nil if key.nil?
    return "%04d" % key
  end

  def make_strings(array)
    return nil if array.nil?
    result = []
    for key in array
      result.push("%04d" % key)
    end
    result
  end

  def make_wset(array)
    return nil if array.nil?
    wset = {}
    for key in array
      wset[key] = 1
    end
    wset
  end

  def feed_doc(id, year, years, myrank)
    doc = Document.new("id:ns:missing::#{id}")
    years_wset = make_wset(years)
    years_s = make_strings(years)
    years_s_wset = make_wset(years_s)
    year_s = make_string(year)
    doc.add_field('years', years) unless years.nil?
    doc.add_field('years_fs', years) unless years.nil?
    doc.add_field('years_wset', years_wset) unless years_wset.nil?
    doc.add_field('years_wset_fs', years_wset) unless years_wset.nil?
    doc.add_field('years_s', years_s) unless years_s.nil?
    doc.add_field('years_s_wset', years_s_wset) unless years_s_wset.nil?
    doc.add_field('year', year) unless year.nil?
    doc.add_field('year_fs', year) unless year.nil?
    doc.add_field('year_s', year_s) unless year_s.nil?
    doc.add_field('myrank', myrank)
    vespa.document_api_v1.put(doc)
  end

  def check_sorted_multi(sortspec, exp_ids)
    for suffix in ['', '_fs', '_wset', '_wset_fs', '_s', '_s_wset']
      adjusted_sortspec = sortspec.gsub('years', "years#{suffix}")
      puts "adjusted_sortspec is #{adjusted_sortspec}"
      check_sorted(adjusted_sortspec, exp_ids)
    end
  end

  def check_sorted_single(sortspec, exp_ids)
    for suffix in ['', '_fs', '_s']
      adjusted_sortspec = sortspec.gsub('year', "year#{suffix}")
      puts "adjusted_sortspec is #{adjusted_sortspec}"
      check_sorted(adjusted_sortspec, exp_ids)
    end
  end

  def check_sorted(sortspec, exp_ids)
    yql = 'select * from sources * where true'
    form = [['yql', yql]]
    form.push(['sortspec', sortspec]) unless sortspec.nil?
    encoded_form = URI.encode_www_form(form)
    puts "encoded_form='#{encoded_form}'"
    result = search("#{encoded_form}")
    assert_hitcount(result, 4)
    puts result
    act_ids = []
    for i in 0...4
      id = result.hit[i].field['documentid'].sub(/id:ns:missing::/, '').to_i
      act_ids.push(id)
    end
    assert_equal(exp_ids, act_ids)
  end

  def check_sorted_error(sortspec)
    yql = 'select * from sources * where true'
    form = [['yql', yql],['sortspec', sortspec]]
    encoded_form = URI.encode_www_form(form)
    puts "encoded_form='#{encoded_form}'"
    result = search("#{encoded_form}")
    assert_not_nil(result.errorlist)
    error = result.errorlist[0]['message']
    puts "Error is #{error}"
    assert_match(/Failed converting string .* to a number/, error)
  end

  def feed_docs
    feed_doc(0,2010, [2010], 8.0)
    feed_doc(1, nil, nil, 7.0)
    feed_doc(2, 2021, [2021, 2005], 6.0)
    feed_doc(3, 2020, [2020], 5.0)
  end

  def teardown
    stop
  end
end
