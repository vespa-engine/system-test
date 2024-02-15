# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class NativeRankResponse < IndexedStreamingSearchTest

# Check that max response of 1 is reachable by nativeRank fieldmatch,
# proximity and attributematch when table normalization is used
  def setup
    set_owner("geirst")
  end

  def test_native_rank_response
    set_description("Test the nativeRank features for dynamic responses in 0-1 range when table normalization is on")

    deploy_app(SearchApp.new.sd(selfdir + "nativerank.sd").
               config(ConfigOverride.new("vespa.configdefinition.ilscripts").
                      add("maxtermoccurrences", 1000)))
    # vespa.adminserver.logctl("configproxy:com.yahoo.vespa.config", "debug=on")
    # vespa.adminserver.logctl("configserver", "debug=on")
    start

    feed_and_wait_for_docs("nativerank", 5, :file => selfdir + "nativerank.xml")

    run_native_rank_reponse_test
  end

  def run_native_rank_reponse_test
    wait_for_hitcount("query=sddocname:nativerank", 5)

    # single term max fieldmatch response = 1
    # one hit has a in field f2 > 256 times
    assert_native_rank(1,  "query=f2:g", "only-fieldmatch", 0)
    assert_native_rank(0.999,  "query=f2:a", "only-fieldmatch", 0) # fieldlength changes because of the b
    assert_native_rank(0.999,  "query=f2:a+f3:b", "only-fieldmatch", 0) # fieldlength changes because of the b and a

    # nativeProximity
    assert_native_rank(1,  "query=f1:a+f1:b", "only-proximity", 0)
    assert_native_rank(0.625,  "query=f2:a+f2:b", "only-proximity", 0)
    assert_native_rank(0.375,  "query=f2:b+f2:a", "only-proximity", 0)
    assert_native_rank(0.625,  "query=f3:b+f3:a", "only-proximity", 0)
    assert_native_rank(0.375,  "query=f3:a+f3:b", "only-proximity", 0)

    # Distance > max => zero proximity
    assert_native_rank(0.0,  "query=f2:c+f2:d", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f2:d+f2:c", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f3:d+f3:c", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f3:c+f3:d", "only-proximity", 0)
    # Distance 100  => zero proximity withing epsilon = 0.001
    assert_native_rank(0.0,  "query=f2:e+f2:f", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f2:f+f2:e", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f3:f+f3:e", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f3:e+f3:f", "only-proximity", 0)

    # no proximity across fields
    assert_native_rank(0.0,  "query=f2:a+f3:b", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f2:c+f3:d", "only-proximity", 0)
    assert_native_rank(0.0,  "query=f2:e+f3:f", "only-proximity", 0)
    # Combined: Only fieldmatch contributes
    assert_native_rank(0.499,  "query=f2:a+f3:b", "fieldmatch-proximity", 0)

    #  nativeAttributematch
    # -termweight and attributeweight must be 1
    assert_native_rank(1,  "query=f4:a", "only-attributematch", 0) # we use linear(1,0) table here
    assert_native_rank(0.502,  "query=f4:a", "only-attributematch", 1)
    assert_native_rank(0.251,  "query=f4:a", "only-attributematch", 2)
    assert_native_rank(0.004,  "query=f4:a", "only-attributematch", 3)
    assert_native_rank(0,  "query=f4:a", "only-attributematch", 4) # check attributematch of this one: 0.95?

    # Combination
    assert_native_rank(1,  "query=f2:a+f4:a", "fieldmatch-attributematch", 0) # why not 1

  end

  def assert_native_rank(score, query, ranking, hit)
    query = query + "&ranking=" + ranking
    query = query + "&rankproperty.vespa.term.0.significance=1&rankproperty.vespa.term.1.significance=1"
    assert_relevancy(query, score, hit, 0.001)
  end

  def teardown
    stop
  end

end
