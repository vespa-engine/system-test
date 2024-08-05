# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'
require 'search/sorting/sorting_base'

class Sorting < IndexedStreamingSearchTest
  # Description: Sorting on a field, ascending, descending, multiple fields
  # Component: Search
  # Feature: Query functionality

  include SortingBase

  def test_sortspec
    #
    # Note: weird names because of OSX case insensitive: sortspec-Loowercase, sortspec-Atttr,
    #                                                    sortspec-Ucca-en_US, sortspec-Ucca-nb_NO
    deploy_app(SearchApp.new.sd(selfdir+"sortspec.sd"))
    start
    #vespa.adminserver.logctl("configproxy:com.yahoo.vespa.config.proxy.RpcConfigSourceClient", "debug=on")
    feed_and_wait_for_docs("sortspec", 8, :file => selfdir+"docs-sortspec.json", :clusters => ["search"])
    wait_for_hitcount("query=sddocname:sortspec", 8)
    # Explicitt sort set in sortspec
    compare("query=sddocname:sortspec&sortspec=-raw(name)",                      "sortspec-attr", "name")
    compare("query=sddocname:sortspec&sortspec=%2Braw(name)",                    "sortspec-Atttr", "name")
    compare("query=sddocname:sortspec&sortspec=-lowercase(name) -raw(name)",     "sortspec-lowercase", "name")
    compare("query=sddocname:sortspec&sortspec=%2Blowercase(name) %2Braw(name)", "sortspec-Loowercase", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name,en_US) -raw(name)",     "sortspec-uca-en_US", "name")
    compare("query=sddocname:sortspec&sortspec=%2Buca(name,en_US) %2Braw(name)", "sortspec-Ucca-en_US", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name,nb_NO) -raw(name)",     "sortspec-uca-nb_NO", "name")
    compare("query=sddocname:sortspec&sortspec=%2Buca(name,nb_NO) %2Braw(name)", "sortspec-Ucca-nb_NO", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name,nb_NO,primary) -raw(name)",        "sortspec-uca-nb_NO_primary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name,nb_NO,secondary) -raw(name)",      "sortspec-uca-nb_NO_secondary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name,nb_NO,tertiary) -raw(name)",       "sortspec-uca-nb_NO_tertiary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name,nb_NO,quaternary) -raw(name)",     "sortspec-uca-nb_NO_quaternary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name,nb_NO,identical) -raw(name)",      "sortspec-uca-nb_NO_identical", "name")

    # Use builtin default
    compare("query=sddocname:sortspec&sortspec=-name -raw(name)",     "sortspec-lowercase", "name")
    compare("query=sddocname:sortspec&sortspec=%2Bname %2Braw(name)", "sortspec-Loowercase", "name")
    # Use builtin ascending(+)sort order.
    compare("query=sddocname:sortspec&sortspec=name raw(name)",       "sortspec-Loowercase", "name")
    # Test order override in .sd
    compare("query=sddocname:sortspec&sortspec=name_ascending raw(name)",       "sortspec-Loowercase", "name")
    compare("query=sddocname:sortspec&sortspec=-name_ascending -raw(name)",     "sortspec-lowercase", "name")
    compare("query=sddocname:sortspec&sortspec=%2Bname_ascending %2Braw(name)", "sortspec-Loowercase", "name")
    compare("query=sddocname:sortspec&sortspec=name_descending -raw(name)",      "sortspec-lowercase", "name")
    compare("query=sddocname:sortspec&sortspec=-name_descending -raw(name)",    "sortspec-lowercase", "name")
    compare("query=sddocname:sortspec&sortspec=%2Bname_descending %2Braw(name)","sortspec-Loowercase", "name")
    # Test function overide in .sd
    compare("query=sddocname:sortspec&sortspec=name_function_raw raw(name_function_raw)",    "sortspec-Atttr", "name")
    compare("query=sddocname:sortspec&sortspec=uca(name_function_raw) raw(name_function_raw)",    "sortspec-Ucca-en_US", "name")
    compare("query=sddocname:sortspec&sortspec=name_function_lowercase raw(name_function_lowercase)",    "sortspec-Loowercase", "name")
    compare("query=sddocname:sortspec&sortspec=uca(name_function_lowercase) raw(name_function_lowercase)",    "sortspec-Ucca-en_US", "name")

    # (override same as default)
    compare("query=sddocname:sortspec&sortspec=name_function_uca raw(name)",    "sortspec-Loowercase", "name")
    compare("query=sddocname:sortspec&sortspec=lowercase(name_function_uca) raw(name_function_uca)", "sortspec-Loowercase", "name")

    # Test locale overide in .sd
    compare("query=sddocname:sortspec&sortspec=name_locale_no raw(name_locale_no)",                   "sortspec-Ucca-nb_NO", "name")
    compare("query=sddocname:sortspec&sortspec=name_locale_no raw(name_locale_no)&language=en_US",    "sortspec-Ucca-nb_NO", "name")
    compare("query=sddocname:sortspec&sortspec=uca(name_locale_no,en_US) raw(name_locale_no)",       "sortspec-Ucca-en_US", "name")

    # check that language= works as expected.
    compare("query=sddocname:sortspec&language=nb-NO&sortspec=uca(name) raw(name)",         "sortspec-Ucca-nb_NO", "name")
    compare("query=sddocname:sortspec&language=nb_NO&sortspec=name_function_uca raw(name)", "sortspec-Ucca-nb_NO", "name")

    # strength set to tertiary.
    compare("query=sddocname:sortspec&sortspec=-name_tertiary -raw(name_tertiary)",       "sortspec-uca-nb_NO_tertiary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name_tertiary,nb_NO,primary) -raw(name_tertiary)",        "sortspec-uca-nb_NO_primary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name_tertiary,nb_NO,PRIMARY) -raw(name_tertiary)",        "sortspec-uca-nb_NO_primary", "name")
    compare("query=sddocname:sortspec&sortspec=-UCA(name_tertiary,nb_NO,primary) -raw(name_tertiary)",        "sortspec-uca-nb_NO_primary", "name")
    compare("query=sddocname:sortspec&sortspec=-UCA(name_tertiary,nb_no,primary) -raw(name_tertiary)",        "sortspec-uca-nb_NO_primary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name_tertiary,nb_NO,secondary) -raw(name_tertiary)",      "sortspec-uca-nb_NO_secondary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name_tertiary,nb_NO,tertiary) -raw(name_tertiary)",       "sortspec-uca-nb_NO_tertiary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name_tertiary,nb_NO,quaternary) -raw(name_tertiary)",     "sortspec-uca-nb_NO_quaternary", "name")
    compare("query=sddocname:sortspec&sortspec=-uca(name_tertiary,nb_NO,identical) -raw(name_tertiary)",      "sortspec-uca-nb_NO_identical", "name")
  end

  def test_sorting
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    start
    feed_and_wait_for_docs("simple", 10000, :file => selfdir+"docs-simple.json", :clusters => ["search"])
    compare_onecluster()
  end

  def test_sorting_2cluster
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new("search").sd(selfdir+"simple.sd")).
               cluster(SearchCluster.new("search2").sd(selfdir+"strong.sd")))
    start
    feed_and_wait_for_docs("simple", 10000, :file => selfdir+"docs-simple.json", :clusters => ["search"])
    feed_and_wait_for_docs("strong", 30, :file => selfdir+"docs-strong.json", :clusters => ["search2"])
    compare_onecluster()
    compare_clustertwo()
    compare_twoclusters()
  end

end
