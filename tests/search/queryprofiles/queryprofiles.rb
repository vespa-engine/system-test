# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class QueryProfiles < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests an application package having query profiles and query profiles types")
  end

  # These tests mostly assigned refers to query profiles setting the default index
  # and uses the number of hits returned as a convenient way to check which query profile has been selected
  # as different default index settings produces different number of hits
  def test_queryprofiles
    deploy_app(SearchApp.new.sd(selfdir + "music.sd").
                             search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("music", 777, :file => selfdir + "../data/music.777.xml")

    # This uses the "default" query profile, which sets default-index to "title", causing 18 hits
    assert_hitcount("query=best", 18)

    # This query profile however, sets default-index to "default", causing 29 hits
    assert_hitcount("query=best&queryProfile=root", 29)

    # ...but the query profile setting can be overridden in the query
    assert_hitcount("query=best&default-index=title&queryProfile=root", 18)

    # ...and using the full name works too
    assert_hitcount("query=best&model.defaultIndex=title&queryProfile=root", 18)

    # ...and so	does setting the value which is used in the substitution
    assert_hitcount("query=best&indexname=title&queryProfile=root", 18)

    # ...and so does alias 1
    assert_hitcount("query=best&Index-name=title&queryProfile=root", 18)

    # ...and alias 2
    assert_hitcount("query=best&IDX=title&queryProfile=root", 18)

    # ...but by using a query profile which makes the default-index unoverridable, the setting is ignored
    assert_hitcount("query=best&default-index=title&queryProfile=root/unoverridableIndex", 29)

    # ...again same result with full name
    assert_hitcount("query=best&model.defaultIndex=title&queryProfile=root/unoverridableIndex", 29)

    # This query profile does not exist, but should resolve to "root", because the type of root specified path matching
    assert_hitcount("query=best&queryProfile=root/nonexisting", 29)

    # Set a model specifying the query (the root query profile sets a type saying the model is a profile)
    # The strange addendum at the end of each line is to trick the test framework into not adding                                  
    # query= to the front of the request string                                                                                    
    assert_hitcount("model=querybest&queryProfile=root&ignore=query=", 18)

    # The same as the above, but using a query profile referencing querybest instead
    # The strange addendum at the end of each line is to trick the test framework into not adding                                      
    # query= to the front of the request string                                                                                        
    assert_hitcount("queryProfile=referingQuerybest&ignore=query=", 18)

    # Setting a non-declared value in a native typed top-level profile works (not bothering to check that it's accessible)
    assert_hitcount("query=best&queryProfile=root&foo=bar", 29)

    # This profile references a type which inherits root, but makes it strict, thus setting foo=bar fails
    assert_result("query=best&queryProfile=rootStrict&foo=bar&hits=0", selfdir + "illegalAssignment.result.json")

    # ...while setting default-index still works
    puts search("query=best&queryProfile=rootStrict&default-index=title").json
    assert_hitcount("query=best&queryProfile=rootStrict&default-index=title", 18) if not is_streaming # Not allow to set streaming.selection with strict query profile

    # Setting a non-declared value in a native typed top-level profile works (not bothering to check that it's accessible)
    assert_hitcount("query=best&queryProfile=root&foo=bar", 29)

    # This query profile makes it mandatory to set "timeout" and "foo"
    assert_result("query=best&queryProfile=mandatory", selfdir + "mandatoryMissing.result.json")

    # ...specifying one does not work (not checking the particular error message again)
    assert_hitcount_with_timeout(3000, "query=best&queryProfile=mandatory", 0)

    # ...not the other (not checking the particular error message again)
    assert_hitcount_withouttimeout("query=best&foo=15&queryProfile=mandatory", 0)

    # ...but specifying both does
    assert_hitcount_with_timeout(3000, "query=best&foo=10&queryProfile=mandatory", 29)

    # Foo is an integer, so giving it a numeric value fails though
    assert_result("query=best&foo=nonumber&hits=9&queryProfile=mandatory", selfdir +  "wrongArgumentType.result.json")

    # This profile uses the same type as above, but specifies the mandatory values
    assert_hitcount("query=best&queryProfile=mandatorySpecified", 29)

    # Testing instance inheritance - this profile inherits all settings from root (punny name unintentional)
    assert_hitcount("query=best&queryProfile=rootChild", 29)

    # Asking for a non-existing query profile fails
    assert_hitcount("query=best&queryProfile=nonexisting", 0)

    # A profile variant
    # The strange addendum at the end of each line is to trick the test framework into not adding 
    # query= to the front of the request string
    assert_hitcount("queryProfile=multi&ignore=query=", 18); # query=title:best
    assert_hitcount("queryProfile=multi&myindex=default&myquery=love&ignore=query=", 196); # query=default:love
    assert_hitcount("queryProfile=multi&myindex=default&ignore=query=", 29); # query=default:best
    assert_hitcount("queryProfile=multi&myindex=default&myquery=notmatched&ignore=query=", 29); # query=default:best
    assert_hitcount("queryProfile=multi&myquery=love&ignore=query=", 9); # query=title:love
    assert_hitcount("queryProfile=multi&myindex=notmatched&myquery=love&ignore=query=", 9); # query=title:love
    assert_hitcount("queryProfile=multi&myindex=notmatched&myquery=notmatched&ignore=query=", 18); # query=title:best
    assert_hitcount("queryProfile=multi&myquery=inheritslove&ignore=query=", 15); # query=default:best filter=+me

    # Test that the dump tool manage to find correct jar files to run.
    dumpresult = vespa.adminserver.execute("vespa-query-profile-dump-tool multi #{dirs.tmpdir}generatedapp")
    assert(dumpresult =~ /model.defaultIndex=title/)
   end

  def teardown
    stop
  end

end
