# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'json'

class Explain < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test explain feature")
  end

  def test_explain
    deploy_app(SearchApp.new.
               cluster_name("basicsearch").
               sd(SEARCH_DATA+"music.sd"))
    start
    feed(:file => SEARCH_DATA+"music.10.json", :timeout => 240, :json => true)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=title:country", 1)
    result = search("/search/?query=sddocname:music&format=json&hits=1&explainlevel=1&tracelevel=1").json
    to_dispatch = result["trace"]["children"][1]["children"][0]["children"][0]["message"]
    assert_match(/sc0.num0 search to dispatch: query=\[\[documentmetastore\]:\*music\*\] timeout=[0-9]+ms offset=0 hits=1 grouping=0 :  rankproperties={"vespa.softtimeout.enable":\[true\]} restrict=\[music\]/, to_dispatch)
    blueprint = result["trace"]["children"][1]["children"][0]["children"][1]["message"][0]["traces"][0]["optimized"]
    assert_equal("search::queryeval::AndBlueprint", blueprint["[type]"])
    assert_equal(11, blueprint["docid_limit"])
    estimate = blueprint["estimate"]
    assert_equal(11, estimate["estHits"])
    assert_equal(3, estimate["tree_size"])
    assert_equal(1, estimate["allow_termwise_eval"])
    #"[type]"=>"search::queryeval::AndBlueprint", "isTermLike"=>false, "estimate"=>{"[type]"=>"HitEstimate", "empty"=>false, "estHits"=>11, "tree_size"=>3, "allow_termwise_eval"=>1}
    #puts result["trace"]["children"][2]
    #tree = JSON.parse(result.xmldata)
    #assert_equal("http://shopping.yahoo.com/shop?d=hab&id=1804905709", tree["root"]["children"][0]["fields"]["surl"])
    #assert_equal("http://shopping.yahoo.com/shop?d=hab&id=1804905710", tree["root"]["children"][1]["fields"]["surl"])
    #assert_equal("http://shopping.yahoo.com/shop?d=hab&id=1804905711", tree["root"]["children"][2]["fields"]["surl"])
  end

  def teardown
    stop
  end

end
