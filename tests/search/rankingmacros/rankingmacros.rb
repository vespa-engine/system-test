# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_search_test'

class RankingMacros < IndexedSearchTest

  def setup
    set_owner("musum")
  end

  def test_deploy_with_unused_macro_as_summary_feature
      deploy_app(SearchApp.new.sd("#{selfdir}/summarymacro.sd"))
  end

  def test_macros
    set_description("Test macro snippets in rank expression")
    deploy_app(SearchApp.new.sd("#{selfdir}/rankingmacros.sd"))
    start
    feed_and_wait_for_docs("rankingmacros", 1, :file => selfdir+"rankingmacros.json")
    result = search("query=title:foo&ranking=standalone");
    score = result.hit[0].field["relevancy"].to_i;
    assert_features({"firstPhase" => 548,
                     "macro_with_dollar$" => 69,
                     "rankingExpression(myfeature)" => 546,
                     "anotherfeature" => 5460,
                     "yetanotherfeature" => 54600},
                     result.hit[0].field['summaryfeatures'], 1e-4)
    assert_equal(score, 4*(1+1));

    result = search("query=title:foo&ranking=constantsAndMacro");
    assert_features({"firstPhase" => 159},
                     result.hit[0].field['summaryfeatures'], 1e-4)
  end

  def teardown
    stop
  end

end
