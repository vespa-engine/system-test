# Copyright Vespa.ai. All rights reserved.
require 'streaming_search_test'
require 'search/sorting/sorting_base'

class SortingStreaming < StreamingSearchTest

  include SortingBase

  def test_sorting_streaming
    set_owner("vekterli")
    deploy_app(singlenode_streaming_2storage(selfdir+"music.sd"))
    start
    feedfile(SEARCH_DATA+"music.777.json")

    puts "sanity check"
    wait_for_hitcount('query=sddocname:music&streaming.selection=true&type=all', 777)
    puts "check sorting:"

    # Need to simulate stemming of queries, by supplying OR queries

    # Query: Ascending sort by year (int index)
    compare('query=(water+waters)+year:[1%3B9999]&sortspec=%2Byear&hits=5&streaming.selection=true&type=all', "sort_water_5", "year")

    # Query: Ascending sort by year (int index)
    compare('query=(water+waters)+year:[1%3B9999]&sortspec=%2Byear&hits=5&offset=10&streaming.selection=true&type=all', "sort_water_offset", "year")

    # Query: Ascending sort by year (int index)
    compare('query=(water+waters)+year:[1%3B9999]&sortspec=%2Byear&hits=100&streaming.selection=true&type=all', "sort_water_all", "year")

    # Query: Descending sort by year (int index)
    compare('query=(water+waters)+year:[1%3B9999]&sortspec=-year&hits=5&streaming.selection=true&type=all', "sort_water_5_descending", "year")

    # Query: Descending sort by year (int index)
    compare('query=(water+waters)+year:[1%3B9999]&sortspec=-year&hits=5&offset=10&streaming.selection=true&type=all', "sort_water_offset_descending", "year")

    # Query: Descending sort by year (int index)
    compare('query=(water+waters)+year:[1%3B9999]&sortspec=-year&hits=100&streaming.selection=true&type=all', "sort_water_all_descending", "year")


    # Query: Ascending sort by title (string index)
    compare('query=(love+loves+loved)&sortspec=%2Btitle&hits=40&streaming.selection=true&type=all', "love_title_sort_ascending", "title")

    # Query: Descending sort by title (string index)
    compare('query=(love+loves+loved)&sortspec=-title&hits=40&streaming.selection=true&type=all', "love_title_sort_descending", "title")


    # Query: Multi-level sorting, first by year, then title (int, string) (ascending, ascending)
    compare('query=(big+bigger)&hits=40&sortspec=%2Byear%20%2Btitle&streaming.selection=true&type=all', "big_year_title_sort", "title")

    # Query: Multi-level sorting, first by year, then title (int, string) (descending, descending)
    compare('query=(big+bigger)&hits=40&sortspec=-year%20-title&streaming.selection=true&type=all', "big_year_title_sort_descending", "title")

    # Query: Multi-level sorting, first by year, then title (int, string) (ascending, descending)
    compare('query=(big+bigger)&hits=40&sortspec=%2byear%20-title&streaming.selection=true&type=all', "big_year_title_sort_both", "title")

    # Ascending sort on rank (use docid to break ties)
    compare('query=this&streaming.selection=true&ranking=onlyweight&sortspec=%2b[rank]%20-[docid]&hits=5&type=all', "this_rank_asc", "documentid")
    # Descending sort on rank (use docid to break ties)
    compare('query=this&streaming.selection=true&ranking=onlyweight&sortspec=-[rank]%20-[docid]&hits=5&type=all', "this_rank_desc", "documentid")

    # Ascending sort on docid (global docid is used for sorting)
    compare('query=this&streaming.selection=true&ranking=onlyweight&sortspec=%2b[docid]&hits=5&type=all', "this_docid_asc", "documentid")
    # Descending sort on docid (global docid is used for sorting)
    compare('query=this&streaming.selection=true&ranking=onlyweight&sortspec=-[docid]&hits=5&type=all', "this_docid_desc", "documentid")

    result = search_with_timeout(60, { 'query' => 'this',
                                       'streaming.selection' => 'true',
                                       'ranking' => 'onlyweight',
                                       'sortspec' => '-badfield',
                                       'hits' => '5',
                                       'type' => 'all' })
    assert_not_nil(result.errorlist)
    assert_match(/Cannot locate field 'badfield' in field name registry/, result.errorlist[0]['message'])
  end

end
