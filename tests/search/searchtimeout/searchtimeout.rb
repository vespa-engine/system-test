# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SearchTimeoutTest < IndexedSearchTest

  def setup
    @valgrind = false
    set_owner("balder")
    set_description("Tests timeout handling in Vespa search")
    deploy_app(SearchApp.new.sd("#{selfdir}/banana.sd").threads_per_search(1))
    start
  end

  def test_timeout_long_firstphase
    feed_and_wait_for_docs("banana", 20, :file => selfdir+"docs.xml")
    assert_result_with_timeout(40.0, "query=sddocname:banana&hits=1&nocache", selfdir + "result.1.json")
    # TODO This will start failing once timeout are best effort.
    assert_query_errors_without_timeout("query=sddocname:banana&hits=1&nocache&timeout=1.0&ranking.softtimeout.enable=false",
                                    ["Timeout while waiting for sc0.num0|Query timed out in sc0.num0"])
    assert_hitcount_withouttimeout("query=sddocname:banana&hits=1&nocache&timeout=40.0", 20)
    assert_hitcount_withouttimeout("query=sddocname:banana&hits=1&nocache&timeout=5.0&ranking.softtimeout.enable=true", 3)
    assert_hitcount_withouttimeout("query=sddocname:banana&hits=1&nocache&timeout=5.0&ranking.softtimeout.enable=true&ranking.softtimeout.factor=0.70", 4)
    for i in 0..40 do
        result = search_base("query=sddocname:banana&hits=1&nocache&timeout=5.0&ranking.softtimeout.enable=true")
        puts "Query " + i.to_s + " has " + result.hitcount.to_s + " hits."
        assert(result.hitcount >= 3)
    end
    assert_hitcount_withouttimeout("query=sddocname:banana&hits=1&nocache&timeout=5.0&ranking.softtimeout.enable=true", 4)
  end

  def teardown
    stop
  end

end
