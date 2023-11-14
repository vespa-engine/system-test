# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
module SortingBase

  def setup
    set_owner("balder")
    set_description("Sorting on a field, ascending, descending, multiple fields")
  end

  def timeout_seconds
    2400
  end

  def compare(query, file, field=nil)
    fname = selfdir+file+".result.json"
    timeout = 20
    puts "Check if #{query} matches #{file}"
    if @valgrind || query.index("&streaming.")
      expect = create_resultset(fname)
      wait_for_hitcount(query, expect.hitcount)
    end
    assert_field(query, fname, field, false, timeout)
  end

  def compare_onecluster
    puts "sanity check"
    assert_hitcount("query=sddocname:simple", 10000)
    puts "check sorting:"

    # Query: Ascending sort by year (int index)
    compare("query=sddocname:simple&sortspec=%2Byear&hits=5", "sort_year_5", "year")
    # Query: Ascending sort by year (int index)
    compare("query=sddocname:simple&sortspec=%2Byear&hits=5&offset=10", "sort_year_offset", "year")
    # Query: Ascending sort by year (int index)
    compare("query=sddocname:simple&sortspec=%2Byear&hits=100", "sort_year_all")

    # Query: Descending sort by year (int index)
    compare("query=sddocname:simple&sortspec=-year&hits=5", "sort_year_5_descending", "year")
    # Query: Descending sort by year (int index)
    compare("query=sddocname:simple&sortspec=-year&hits=5&offset=10", "sort_year_offset_descending", "year")
    # Query: Descending sort by year (int index)
    compare("query=sddocname:simple&sortspec=-year&hits=100", "sort_year_all_descending", "year")

    # Query: Ascending sort by category (string index)
    compare("query=sddocname:simple&sortspec=%2Bcategory&hits=40", "category_sort_asc", "category")
    # Query: Descending sort by category (string index)
    compare("query=sddocname:simple&love&sortspec=-category&hits=40", "category_sort_desc", "category")

    compare("query=sddocname:simple&sortspec=%2Blastname_lc&hits=5",    "sort_lname_5_a", "lastname")
    compare("query=sddocname:simple&sortspec=-lastname_lc&hits=5",      "sort_lname_5_d", "lastname")

    # Query: Multi-level sorting, first by category, then year, (string, int) (ascending, ascending)
    compare("query=sddocname:simple&sortspec=%2Bcategory+%2Byear", "aa_year_category", "year")
    compare("query=sddocname:simple&sortspec=%2Bcategory+%2Byear", "aa_year_category", "category")

    # Query: Multi-level sorting, first by category, then year, (string, int) (descending, descending)
    compare("query=sddocname:simple&sortspec=-category%20-year", "dd_year_category", "year")
    compare("query=sddocname:simple&sortspec=-category%20-year", "dd_year_category", "category")

    # Query: Multi-level sorting, first by category, then year, (string, int) (ascending, descending)
    compare("query=sddocname:simple&sortspec=-category%20%2byear", "ad_year_category", "year")
    compare("query=sddocname:simple&sortspec=-category%20%2byear", "ad_year_category", "category")

    # Query: Regular, default no-frills sorting (aka "ranking")
    compare("query=sddocname:simple+17", "17", "title")

    # Query: Modify (Regular) query by adding '-[rank] in sortspec"
    # (should give exact same answer as default order)
    compare("query=sddocname:simple+17&sortspec=-[rank]", "17", "title")
    compare("query=sddocname:simple+17&sortspec=-[relevance]", "17", "title")
    compare("query=sddocname:simple+17&sortspec=-[relevancy]", "17", "title")

    # Query: Modify (Regular) query by adding '+[rank]' in sortspec
    compare("query=sddocname:simple+17&sortspec=%2b[rank]", "17_reverse", "title")

    # tickle a bug where the QRS would sort on rank (only) in the first phase
    compare("query=sddocname:simple+17&sortspec=-year%20-[rank]", "17_year_rank", "title")
    compare("query=sddocname:simple+17&sortspec=-category%20-[rank]", "17_cat_rank", "title")
    # Query: Ascending sort by bool (odd)
    compare("query=sddocname:simple+17&sortspec=%2Bodd%20-year%20-[rank]", "17_false_true_rank", "title")
    compare("query=sddocname:simple+17&sortspec=-odd%20-year%20-[rank]", "17_true_false_rank", "title")
  end

  def compare_twoclusters
    puts "sanity check"
    assert_hitcount("query=(sddocname:strong+sddocname:simple+)", 10000+30)
    puts "check sorting:"

    compare("query=59&sortspec=%2Byear&hits=15", "both_year_a", "year")
    compare("query=59&sortspec=-year&hits=15",   "both_year_d", "year")

    compare("query=(17+sddocname:strong+)&sortspec=raw(category)&hits=5", "both_cat_a", "category")
    compare("query=(17+sddocname:strong+)&sortspec=-raw(category)&hits=5",   "both_cat_d", "category")

    compare("query=(59+sddocname:strong+)&sortspec=raw(category)&hits=55", "both_big_a", "category")
    compare("query=(59+sddocname:strong+)&sortspec=-raw(category)&hits=55",   "both_big_d", "category")
  end

  def compare_clustertwo
    puts "sanity check"
    assert_hitcount("query=sddocname:strong", 30)
    puts "check sorting:"

    compare("query=sddocname:strong&sortspec=%2Byear&hits=5",           "strong_year_5", "year")
    compare("query=sddocname:strong&sortspec=%2Byear&hits=5&offset=10", "strong_year_offset", "year")
    compare("query=sddocname:strong&sortspec=%2Byear&hits=100",         "strong_year_all")
    compare("query=sddocname:strong&sortspec=-year&hits=5",             "strong_year_5_descending",      "year")
    compare("query=sddocname:strong&sortspec=-year&hits=5&offset=10",   "strong_year_offset_descending", "year")
    compare("query=sddocname:strong&sortspec=-year&hits=100",           "strong_year_all_descending",    "year")
    compare("query=sddocname:strong&sortspec=%2Bcategory&hits=40",      "strong_category_asc", "category")
    compare("query=sddocname:strong&love&sortspec=-category&hits=40",   "strong_category_desc", "category")
    compare("query=sddocname:strong&sortspec=%2Bcategory+%2Byear",      "strong_aa_year_category", "year")
    compare("query=sddocname:strong&sortspec=%2Bcategory+%2Byear",      "strong_aa_year_category", "category")
    compare("query=sddocname:strong&sortspec=-category%20-year",        "strong_dd_year_category", "year")
    compare("query=sddocname:strong&sortspec=-category%20-year",        "strong_dd_year_category", "category")
    compare("query=sddocname:strong&sortspec=-category%20%2byear",      "strong_ad_year_category", "year")
    compare("query=sddocname:strong&sortspec=-category%20%2byear",      "strong_ad_year_category", "category")

    compare("query=sddocname:strong&sortspec=%2Blastname_lc&hits=5",    "strong_lname_5_a", "lastname")
    compare("query=sddocname:strong&sortspec=-lastname_lc&hits=5",      "strong_lname_5_d", "lastname")

    compare("query=sddocname:strong",                                   "strong",           "name")
    compare("query=sddocname:strong&sortspec=-[rank]",                  "strong",           "name")
    compare("query=sddocname:strong&sortspec=%2b[rank]",                "strong_reverse",   "name")
    compare("query=sddocname:strong&sortspec=-year%20-[rank]",          "strong_year_rank", "name")
    compare("query=sddocname:strong&sortspec=-category%20-[rank]",      "strong_rank",      "name")

    puts "check sorting that is only valid in one of two clusters:"
    qallww = "sddocname:strong+weight:[-9999%3B9999]"

    compare("query=#{qallww}&sortspec=-weight&hits=5",                  "strong_weight_5_d", "weight")
    compare("query=#{qallww}&sortspec=%2Bweight&hits=5",                "strong_weight_5_a", "weight")
    compare("query=#{qallww}&sortspec=-weight&hits=5",                  "strong_weight_5_d", "year")
    compare("query=#{qallww}&sortspec=%2Bweight&hits=5",                "strong_weight_5_a", "year")

    puts "check docid sorting (depends on ordered feed):"
    compare("query=sddocname:strong&sortspec=-[docid]",                 "strong_docid_d", "name")
    compare("query=sddocname:strong&sortspec=%2B[docid]",               "strong_docid_a", "name")
  end

  def teardown
    stop
  end

end
