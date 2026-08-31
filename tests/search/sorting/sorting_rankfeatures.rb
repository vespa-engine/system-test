# Copyright Vespa.ai. All rights reserved.

require 'search_test'

class SortingRankFeatures < SearchTest

  # Description: Sorting on rank features declared in a rank profile's sort-features block
  # Component: Search
  # Feature: Query functionality

  QUERY = 'select * from sources * where title contains "alpha"'

  def setup
    set_owner('arnej')
    set_description('Test sorting on rank features listed in sort-features')
  end

  # Documents (see docs-rankfeatures.json), all matching "alpha":
  #
  #  id | title occurrences | year | price | category | inv_price | decade
  #  ---+-------------------+------+-------+----------+-----------+-------
  #   0 | 1                 | 2001 |  10.0 | red      |     990.0 |    200
  #   1 | 2                 | 2002 |  30.0 | blue     |     970.0 |    200
  #   2 | 3                 | 2013 |  20.0 | red      |     980.0 |    201
  #   3 | 4                 | 2014 |  50.0 | blue     |     950.0 |    201
  #   4 | 5                 | 2025 |  40.0 | red      |     960.0 |    202
  #
  # bm25(title) grows with the number of occurrences, so it orders 0 < 1 < 2 < 3 < 4.
  # The first-phase score is attribute(year), which orders 0 < 1 < 2 < 3 < 4 as well.

  def test_sort_by_rank_feature
    deploy_app(SearchApp.new.sd(selfdir + 'rankfeatures.sd'))
    start
    feed_and_wait_for_docs('rankfeatures', 5, :file => selfdir + 'docs-rankfeatures.json')

    check_single_level_sorting
    check_multi_level_sorting
    check_ranking_is_not_activated
    check_offset_and_hits
    check_yql_ordering
    check_inheritance
    check_errors
  end

  # A rank feature can only be used for sorting when the schema is indexed
  def test_sort_by_rank_feature_streaming
    deploy_app(SearchApp.new.sd(selfdir + 'rankfeatures.sd').streaming)
    start

    # The query is rejected in the container, so no documents are needed
    check_error({ 'ranking' => 'sorting', 'sortspec' => '-feature(inv_price)',
                  'streaming.selection' => 'true' },
                /cannot sort by feature\(inv_price\).*is not indexed/)
  end

  def check_single_level_sorting
    # ascending inv_price is descending price
    check_order({ 'ranking' => 'sorting', 'sortspec' => '+feature(inv_price)' }, [3, 4, 1, 2, 0])
    check_order({ 'ranking' => 'sorting', 'sortspec' => '-feature(inv_price)' }, [0, 2, 1, 4, 3])
    # unlike attribute sorting, feature sorting defaults to ascending
    check_order({ 'ranking' => 'sorting', 'sortspec' => 'feature(inv_price)' }, [3, 4, 1, 2, 0])

    # a feature using the query, not just attributes
    check_order({ 'ranking' => 'sorting', 'sortspec' => '+feature(title_bm25)' }, [0, 1, 2, 3, 4])
    check_order({ 'ranking' => 'sorting', 'sortspec' => '-feature(title_bm25)' }, [4, 3, 2, 1, 0])

    # a built-in feature (not a function, so not renamed on the way to the backend).
    # The scores depend on the nativeRank tuning, so instead of a fixed order we
    # check that it gives a total order, descending being the reverse of ascending.
    ascending = feature_sorted_ids({ 'ranking' => 'sorting', 'sortspec' => '+feature(nativeRank)' })
    descending = feature_sorted_ids({ 'ranking' => 'sorting', 'sortspec' => '-feature(nativeRank)' })
    assert_equal([0, 1, 2, 3, 4], ascending.sort)
    assert_equal(ascending.reverse, descending)
  end

  def check_multi_level_sorting
    # decade is a tie for {0,1} and {2,3}, broken by the second sort level
    check_order({ 'ranking' => 'sorting', 'sortspec' => '+feature(decade) -[rank]' }, [1, 0, 3, 2, 4])
    check_order({ 'ranking' => 'sorting', 'sortspec' => '+feature(decade) +[rank]' }, [0, 1, 2, 3, 4])
    # feature followed by attribute
    check_order({ 'ranking' => 'sorting', 'sortspec' => '+feature(decade) +price' }, [0, 1, 2, 3, 4])
    check_order({ 'ranking' => 'sorting', 'sortspec' => '-feature(decade) -price' }, [4, 3, 2, 1, 0])
    # feature followed by feature
    check_order({ 'ranking' => 'sorting', 'sortspec' => '+feature(decade) -feature(inv_price)' }, [0, 1, 2, 3, 4])
    # attribute followed by feature
    check_order({ 'ranking' => 'sorting', 'sortspec' => '+category -feature(inv_price)' }, [1, 3, 0, 2, 4])
    # the same feature used twice
    check_order({ 'ranking' => 'sorting', 'sortspec' => '-feature(inv_price) +feature(inv_price)' }, [0, 2, 1, 4, 3])
  end

  # Sorting on a rank feature alone does not activate ranking, so all hits get relevance 0.
  # Adding [rank] to the sort spec brings ranking back.
  def check_ranking_is_not_activated
    result = check_order({ 'ranking' => 'sorting', 'sortspec' => '-feature(inv_price)' }, [0, 2, 1, 4, 3])
    assert_relevancies(result, [0.0, 0.0, 0.0, 0.0, 0.0])

    result = check_order({ 'ranking' => 'sorting', 'sortspec' => '-feature(inv_price) -[rank]' }, [0, 2, 1, 4, 3])
    assert_relevancies(result, [2001.0, 2013.0, 2002.0, 2025.0, 2014.0])

    # second-phase ranking is not run either
    result = check_order({ 'ranking' => 'with_second_phase', 'sortspec' => '-feature(inv_price)' }, [0, 2, 1, 4, 3])
    assert_relevancies(result, [0.0, 0.0, 0.0, 0.0, 0.0])

    result = check_order({ 'ranking' => 'with_second_phase', 'sortspec' => '-feature(inv_price) -[rank]' }, [0, 2, 1, 4, 3])
    assert_relevancies(result, [200100.0, 201300.0, 200200.0, 202500.0, 201400.0])
  end

  def check_offset_and_hits
    result = do_search({ 'ranking' => 'sorting', 'sortspec' => '+feature(inv_price)',
                         'hits' => '2', 'offset' => '1' })
    assert_no_errors(result)
    assert_hitcount(result, 5)
    assert_equal([4, 1], ids_of(result))
  end

  def check_yql_ordering
    yql = QUERY + ' order by [{"function": "feature"}]inv_price desc'
    result = do_search({ 'yql' => yql, 'ranking' => 'sorting' })
    assert_no_errors(result)
    assert_hitcount(result, 5)
    assert_equal([0, 2, 1, 4, 3], ids_of(result))

    yql = QUERY + ' order by [{"function": "feature"}]inv_price asc'
    result = do_search({ 'yql' => yql, 'ranking' => 'sorting' })
    assert_no_errors(result)
    assert_equal([3, 4, 1, 2, 0], ids_of(result))
  end

  def check_inheritance
    check_order({ 'ranking' => 'sorting_child', 'sortspec' => '-feature(inv_price)' }, [0, 2, 1, 4, 3])
    check_order({ 'ranking' => 'with_second_phase', 'sortspec' => '+feature(decade) +price' }, [0, 1, 2, 3, 4])
  end

  def check_errors
    # not listed in sort-features
    check_error({ 'ranking' => 'sorting', 'sortspec' => '-feature(no_such_feature)' },
                /cannot sort by feature\(no_such_feature\).*does not allow it/)
    # the function exists, but the rank profile has no sort-features at all
    check_error({ 'ranking' => 'no_sort_features', 'sortspec' => '-feature(inv_price)' },
                /cannot sort by feature\(inv_price\).*does not allow it/)
    # inherited sort-features cleared by an empty block
    check_error({ 'ranking' => 'sorting_cleared', 'sortspec' => '-feature(inv_price)' },
                /cannot sort by feature\(inv_price\).*does not allow it/)
    # the default rank profile does not allow it either
    check_error({ 'sortspec' => '-feature(inv_price)' },
                /cannot sort by feature\(inv_price\).*does not allow it/)
    # only bare schema identifiers are legal feature names
    check_error({ 'ranking' => 'sorting', 'sortspec' => '-feature(inv.price)' },
                /Illegal feature name 'inv\.price' for sorting/)
    # missing() does not apply to features, they always have a value
    check_error({ 'ranking' => 'sorting', 'sortspec' => '-missing(feature(inv_price),first)' },
                /Cannot use missing\(\) with feature\(\.\.\.\) sorting/)
  end

  def do_search(params)
    form = { 'yql' => QUERY, 'hits' => '10' }.merge(params)
    encoded_form = URI.encode_www_form(form.to_a)
    puts "Query: #{encoded_form}"
    search(encoded_form)
  end

  def ids_of(result)
    (0...result.hit.size).map do |i|
      result.hit[i].field['documentid'].sub(/id:test:rankfeatures::/, '').to_i
    end
  end

  def assert_no_errors(result)
    assert_nil(result.errorlist, "Unexpected error(s): #{result.errorlist}")
  end

  def check_order(params, exp_ids)
    result = do_search(params)
    assert_no_errors(result)
    assert_hitcount(result, 5)
    assert_equal(exp_ids, ids_of(result))
    result
  end

  # Returns the hit ids of a query sorting on a rank feature only, where all
  # hits are expected to be unranked
  def feature_sorted_ids(params)
    result = do_search(params)
    assert_no_errors(result)
    assert_hitcount(result, 5)
    assert_relevancies(result, [0.0] * 5)
    ids_of(result)
  end

  def assert_relevancies(result, exp_relevancies)
    act_relevancies = (0...result.hit.size).map { |i| result.hit[i].field['relevancy'].to_f }
    assert_equal(exp_relevancies, act_relevancies)
  end

  def check_error(params, exp_message)
    result = do_search(params)
    assert_not_nil(result.errorlist, "Expected an error, got #{result}")
    message = result.errorlist[0]['message']
    puts "Error is #{message}"
    assert_match(exp_message, message)
  end

end
