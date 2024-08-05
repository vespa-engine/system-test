# Copyright Vespa.ai. All rights reserved.
require 'search_test'
require 'set'

class MixedModeClustersTest < SearchTest

  def setup
    set_owner("baldersheim")
  end

  def test_mixed_mode_clusters
    set_description("Test multiple content clusters with mixed mode documents")
    deploy_app(SearchApp.new.sd(selfdir + "a1indexed.sd", :mode => "index")
                            .sd(selfdir + "a1streaming.sd", :mode => "streaming")
                            .sd(selfdir + "a1storeonly.sd", :mode => "store-only"))
    start
    feed(:file => selfdir + "docs.json")

    check_q('text contains "first"', "*", 2)
    check_q('text contains "first"', "search", 2)
    check_q('text contains "first"', "search.a1streaming", 1)
    check_q('text contains "first"', "search.a1indexed", 1)
    check_q('text contains "first"', "search.a1storeonly", 0)
  end

  def check_q(where, source, exp_hits)
    query = "yql=select * from sources #{source} where #{where}&streaming.selection=true"
    puts "Result = " + search(query).json.to_s
    assert_hitcount(query, exp_hits)
  end

  def teardown
    stop
  end

end
