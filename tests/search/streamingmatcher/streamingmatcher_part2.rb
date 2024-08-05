# Copyright Vespa.ai. All rights reserved.
require 'search/streamingmatcher/streaming_matcher'

class StreamingMatcherPart2 < StreamingMatcher

  def self.final_test_methods
    ["test_multiple_sd_in_content","test_elastic"]
  end

  def test_phrase_search
    set_owner("balder")
    set_description("Test phrase search for streaming matcher")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"phrase.sd"))
    start
    feed(:file => selfdir + "phrase.json")
    wait_for_hitcount('query=a+b&streaming.userid=1&type=all', 2)

    assert_hitcount('query=%22a%22&streaming.userid=1&type=all', 2)
    assert_hitcount('query=%22a b%22&streaming.userid=1&type=all', 1)
    assert_hitcount('query=%22a b c%22&streaming.userid=1&type=all', 0) # no interference between fields
    assert_hitcount('query=%22a b d%22&streaming.userid=1&type=all', 0) # no interference between fields
    assert_hitcount('query=%22a b e%22&streaming.userid=1&type=all', 0) # no interference between fields
    assert_hitcount('query=%22a b f%22&streaming.userid=1&type=all', 0) # no interference between fields
    assert_hitcount('query=%22c b e%22&streaming.userid=1&type=all', 0) # no interference between fields postions
    assert_hitcount('query=%22a x d%22&streaming.userid=1&type=all', 0) # no interference between fields postions
    assert_hitcount('query=%22c x b%22&streaming.userid=1&type=all', 0) # no interference between fields postions
    assert_hitcount('query=%22d e%22&streaming.userid=1&type=all', 1)
    assert_hitcount('query=%22d e f%22&streaming.userid=1&type=all', 1)
    assert_hitcount('query=%22d e f x%22&streaming.userid=1&type=all', 0)

    assert_hitcount('query=f1:%22a b%22&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f2:%22a b%22&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f1:%22d e f%22&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f2:%22d e f%22&streaming.userid=1&type=all', 1)
  end

  def test_multilevel_sorting
    set_owner("balder")
    set_description("Test sorting on nested fields")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"sortaggr.sd"))
    start
    feed(:file => selfdir + "sortingfeed.json")
    wait_for_hitcount('query=sddocname:sortaggr&streaming.userid=1&type=all', 8)

    assert_result_order('query=sddocname:sortaggr&sorting=-f1.s1 %2b[docid]&streaming.userid=1&type=all',     [2, 1, 4, 7, 0, 3, 5, 6])
    assert_result_order('query=sddocname:sortaggr&sorting=-f1.s1 -[docid]&streaming.userid=1&type=all',     [2, 7, 4, 1, 6, 5, 3, 0])
    assert_result_order('query=sddocname:sortaggr&sorting=-f1.s1 -f4&streaming.userid=1&type=all',        [2, 4, 1, 7, 5, 0, 6, 3])
    assert_result_order('query=sddocname:sortaggr&sorting=-f1.s1 %2bf4&streaming.userid=1&type=all',      [2, 7, 1, 4, 3, 6, 0, 5])
    assert_result_order('query=sddocname:sortaggr&sorting=%2bf1.s1 %2b[docid]&streaming.userid=1&type=all',   [0, 3, 5, 6, 1, 4, 7, 2])
    assert_result_order('query=sddocname:sortaggr&sorting=%2bf1.s1 -[docid]&streaming.userid=1&type=all',    [6, 5, 3, 0, 7, 4, 1, 2])
    assert_result_order('query=sddocname:sortaggr&sorting=%2bf1.s1 -f4&streaming.userid=1&type=all',      [5, 0, 6, 3, 4, 1, 7, 2])
    assert_result_order('query=sddocname:sortaggr&sorting=%2bf1.s1 %2bf4&streaming.userid=1&type=all',    [3, 6, 0, 5, 7, 1, 4, 2])
    assert_result_order('query=sddocname:sortaggr&sorting=%2bf1.s1 %2bf4&ranking=unranked&streaming.userid=1&type=all',    [3, 6, 0, 5, 7, 1, 4, 2])
    assert_result_order('query=sddocname:sortaggr&sorting=%2bf1.s1+%2Bf4&ranking=unranked&streaming.userid=1&type=all',    [3, 6, 0, 5, 7, 1, 4, 2])

    assert_result_order('query=sddocname:sortaggr&sorting=-f5.u1.s1 -f5.u1.i1&streaming.userid=1&type=all', [3, 6, 4, 1, 0, 7, 5, 2])
  end

  def test_sorting
    set_owner("balder")
    set_description("Test sorting on nested fields")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"sortaggr.sd"))
    start
    feed(:file => selfdir + "sortaggr.json")
    wait_for_hitcount('query=sddocname:sortaggr&streaming.userid=1&type=all', 8)

    # sorting on nested fields
    assert_result_order('query=sddocname:sortaggr&sorting=-f1.s1&streaming.userid=1&type=all',            [7, 6, 5, 4, 3, 2, 1, 0])
    assert_result_order('query=sddocname:sortaggr&sorting=%2Bf1.s1&streaming.userid=1&type=all',          [0, 1, 2, 3, 4, 5, 6, 7])
    assert_result_order('query=sddocname:sortaggr&sorting=%2Bf1.i1+%2Bf1.s1&streaming.userid=1&type=all', [3, 7, 2, 6, 1, 5, 0, 4])
    assert_result_order('query=sddocname:sortaggr&sorting=-f1.i1+-f1.s1&streaming.userid=1&type=all',     [4, 0, 5, 1, 6, 2, 7, 3])
  end

  def test_not_defined_values
    set_owner("geirst")
    set_description("Test that not defined values are shown correctly in document summary")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"notdef.sd"))
    start
    feed(:file => selfdir + "notdef.json")
    wait_for_hitcount('query=sddocname:notdef&streaming.userid=1&type=all', 1)

    assert_result_matches('query=sddocname:notdef&streaming.userid=1&format=xml&type=all', selfdir + "notdef.result", /field name="f/)
  end


  def test_match_types
    set_owner("geirst")
    set_description("Test various match types for a field and overrides in query")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"matchtypes.sd").
                   config(ConfigOverride.new("vespa.config.search.core.proton").
                          add("summary", ConfigValue.new("cache", ConfigValue.new("allowvisitcaching", "true")))).
                   tune_searchnode({:summary => {:store => {:cache => {:maxsize => 10000000}}}}))
    start
    feed(:file => selfdir + "matchtypes.json")
    wait_for_hitcount('query=sddocname:matchtypes&streaming.userid=1&type=all', 1)

    puts "complete match"
    assert_hitcount('query=f1:field&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f2:field&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:field&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:field&streaming.userid=1&type=all', 1)

    puts "prefix match"
    assert_hitcount('query=f1:fiel&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f2:fiel&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f2:fiel+f2:pre&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:fiel&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:fiel&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f1:fiel%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f2:fiel%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:fiel%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:fiel%2A&streaming.userid=1&type=all', 1)

    puts "substring match"
    assert_hitcount('query=f1:iel&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f2:iel&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f3:iel&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:iel+f3:ubs&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:iel&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f1:%2Aiel%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f2:%2Aiel%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:%2Aiel%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:%2Aiel%2A&streaming.userid=1&type=all', 1)
    # extras
    assert_hitcount('query=f3:eld&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f1:%2Aeld%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:y&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f1:%2Ay%2A&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:asma&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f1:%2Aasma%2A&streaming.userid=1&type=all', 0)

    puts "suffix match"
    assert_hitcount('query=f1:eld&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f2:eld&streaming.userid=1&type=all', 0)
    assert_hitcount('query=f3:eld&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:eld&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:eld+f4:ffix&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f1:%2Aeld&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f2:%2Aeld&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f3:%2Aeld&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f4:%2Aeld&streaming.userid=1&type=all', 1)
    # extras
    assert_hitcount('query=f1:%2Afield&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f1:%2Ad&streaming.userid=1&type=all', 1)
    assert_hitcount('query=f1:%2Asfield&streaming.userid=1&type=all', 0)

    puts "combinations"
    assert_hitcount('query=f1:field+f1:%2Aiel%2A&streaming.userid=1&type=all', 1) # normal and substring
    assert_hitcount('query=f1:field+f1:%2Aeld&streaming.userid=1&type=all',  1) # normal and suffix
    assert_hitcount('query=f1:fiel%2A+f1:%2Aiel%2A&streaming.userid=1&type=all', 1) # both prefix and substring
    assert_hitcount('query=f1:iel+f1:%2Aiel%2A&streaming.userid=1&type=all',   0) # substring only for the term specified
    assert_hitcount('query=f1:eld+f1:%2Aeld&streaming.userid=1&type=all',    0) # suffix only for the term specified
    assert_hitcount('query=f1:%2Aiel%2A+f2:iel&streaming.userid=1&type=all',   0) # substring only for f1
    assert_hitcount('query=f1:%2Aiel%2A+f2:%2Aiel%2A&streaming.userid=1&type=all', 1) # substring for both f1 and f2
    assert_hitcount('query=f2:iel+f2:%2Aiel%2A&streaming.userid=1&type=all',   0) # substring only for the term specified
    assert_hitcount('query=f2:fie+f2:fie%2A+f2:%2Aiel%2A+f2:%2Aeld&streaming.userid=1&type=all', 1) # prefix property should still work
    assert_hitcount('query=f3:iel+f3:fie%2A+f3:%2Aiel%2A+f3:%2Aeld&streaming.userid=1&type=all', 1) # substring property should still work
    assert_hitcount('query=f4:eld+f4:fie%2A+f4:%2Aiel%2A+f4:%2Aeld&streaming.userid=1&type=all', 1) # suffix property should still work

    puts "default index"
    assert_hitcount('query=iel&streaming.userid=1&type=all',   1) # f3 is of type substring
    assert_hitcount('query=efa&streaming.userid=1&type=all',   0) # f1 is not of type substring
    assert_hitcount('query=ref&streaming.userid=1&type=all',   0) # f2 is not of type substring
    assert_hitcount('query=pref&streaming.userid=1&type=all',  1) # f2 is of type prefix
    assert_hitcount('query=ffix&streaming.userid=1&type=all',  1) # f4 is of type suffix
    assert_hitcount('query=%2Aefa%2A&streaming.userid=1&type=all', 1) # override
    assert_hitcount('query=%2Aref%2A&streaming.userid=1&type=all', 1) # override
    assert_hitcount('query=eld%2A&streaming.userid=1&type=all',  1) # override
  end


  def test_dynamic_summary
    set_owner("geirst")
    set_description("Test dynamic summary with multiple input fields")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"dynsum.sd"))
    start
    feed(:file => selfdir + "dynsum.json")
    wait_for_hitcount('query=sddocname:dynsum&streaming.userid=1&type=all', 2)

    assert_result('query=a&streaming.userid=1&type=all',   selfdir + "dynsum.a.result.json", nil, ["sum1","sum2"])
    assert_result('query=a+b&streaming.userid=1&type=all', selfdir + "dynsum.ab.result.json", nil, ["sum1","sum2"])
    assert_result('query=xyz&streaming.userid=1&type=all', selfdir + "dynsum.xyz.result.json", nil, ["sum1","sum2"])
    assert_result('query=sddocname:dynsum&streaming.userid=1&type=all', selfdir + "dynsum.sddoc.result.json", "sum1", ["sum1","sum2"])
    assert_equal(true, search('query=a&streaming.userid=1&type=all').hit[0].field.has_key?("f1"))
    assert_equal(true, search('query=a&streaming.userid=1&type=all').hit[0].field.has_key?("f2"))
  end


  def test_explicit_summary_name
    set_owner("geirst")
    set_description("Test summary fields with explicit names different than the field names.")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"expsumname.sd"))
    start
    feed(:file => selfdir + "expsumname.json")
    wait_for_hitcount('query=sddocname:expsumname&streaming.userid=1&type=all', 1)

    result = search('query=sddocname:expsumname&streaming.userid=1&format=xml&type=all')
    assert_equal("1072443443000", result.hit[0].field["slong"])
    assert_equal("107.443", result.hit[0].field["sdouble"])
    assert_equal("something", result.hit[0].field["sstring"])
    assert_equal(false, result.hit[0].field.has_key?("flong"))
    assert_equal(false, result.hit[0].field.has_key?("fdouble"))
    assert_equal(false, result.hit[0].field.has_key?("fstring"))
  end

  def test_illegal_rank
    set_expected_logged(/searchvisitor\.rankmanager.*error.*\(re-\)configuration of rank manager failed/)
    set_owner("geirst")
    set_description("Test that we cannot create a search visitor when we have an illegal rank setup")
    begin
      err = deploy_app(SearchApp.new.streaming().sd(selfdir+"illegalrank.sd"))
    rescue ExecuteError => e
      err = e.output
      assert(err.include?('verification failed: rank feature illegal'))
      return
    end
    start
    feed(:file => selfdir + "illegalrank.json")
    wait_for_hitcount('query=f1:illegal&streaming.userid=1&type=all', 0)
    assert_log_matches(/.*\(re-\)configuration of rank manager failed/)
  end


  def test_heap_property
    set_owner("geirst")
    set_description("Test that the hit heap in streaming works as expected")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"heap.sd"))
    start
    feed(:file => selfdir + "heap.json")
    wait_for_hitcount('query=sddocname:heap&streaming.userid=1&type=all', 12)

    # ranking (summary/rank features should be available for all hits)
    assert_heap_property(get_query(12), [11,10,9,8,7,6,5,4,3,2,1,0])
    assert_heap_property(get_query(13), [11,10,9,8,7,6,5,4,3,2,1,0])
    assert_heap_property(get_query(2, 0),  [11,10])
    assert_heap_property(get_query(2, 2),  [9,8])
    assert_heap_property(get_query(2, 4),  [7,6])
    assert_heap_property(get_query(2, 6),  [5,4])
    assert_heap_property(get_query(2, 8),  [3,2])
    assert_heap_property(get_query(2, 10), [1,0])
    assert_heap_property(get_query(2, 12), [])

    # sorting (summary/rank features should be available for all hits)
    sort_spec = "%2Bf1"
    assert_heap_property(get_query(12, 0, sort_spec), [0,1,2,3,4,5,6,7,8,9,10,11])
    assert_heap_property(get_query(13, 0, sort_spec), [0,1,2,3,4,5,6,7,8,9,10,11])
    assert_heap_property(get_query(2, 0, sort_spec),  [0,1])
    assert_heap_property(get_query(2, 2, sort_spec),  [2,3])
    assert_heap_property(get_query(2, 4, sort_spec),  [4,5])
    assert_heap_property(get_query(2, 6, sort_spec),  [6,7])
    assert_heap_property(get_query(2, 8, sort_spec),  [8,9])
    assert_heap_property(get_query(2, 10, sort_spec), [10,11])
    assert_heap_property(get_query(2, 12, sort_spec), [])
  end

  def test_elastic
    set_owner("musum")
    deploy(selfdir + "app_elastic")
    start
    feed(:file => selfdir + "app_elastic/books.json")
    feed(:file => selfdir + "app_elastic/music.json")
    wait_for_hitcount('query=best&streaming.selection=true&type=all', 4)
  end

  def test_multiple_sd_in_content
    set_owner("balder")
    set_description("Test that content cluster takes multiple schemas")
    deploy(selfdir + "app_multiple_sd_in_content", [selfdir + "app_elastic/schemas/music.sd", selfdir + "app_elastic/schemas/books.sd"])
    start
    feed(:file => selfdir + "app_elastic/books.json")
    feed(:file => selfdir + "app_elastic/music.json")
    wait_for_hitcount('query=best&streaming.selection=true&type=all', 4)
  end

end
