# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class SemanticSearcher < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Simple test for semantics module")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").rules_dir(selfdir+"rules"))
    vespa.container.each_value do |qrs|
      qrs.copy(selfdir+"stopwords.fsa", Environment.instance.vespa_home + "/etc/vespa/fsa")
    end
    start
  end

  def test_semantic_searcher
    feed_and_wait_for_docs("music", 777, :file => selfdir+"simpler.777.xml")

    puts "Details: query=bach"
    assert_result("query=bach&hits=8", selfdir+"bach.result", "title")

    puts "Details: query=bahc&hits=8&rules.rulebase=common"
    assert_result("query=bahc&hits=8&rules.rulebase=common",
                  selfdir+"bach.result", "title")

    puts "Details: query=bach+somelongstopword&hits=8&rules.rulebase=common"
    assert_result("query=bach+somelongstopword&hits=8&rules.rulebase=common",
                  selfdir+"bach.result", "title")

    puts "Details: query=bahc+someotherlongstopword&hits=8&rules.rulebase=common"
    assert_result("query=bahc+someotherlongstopword&hits=8&rules.rulebase=common",
                  selfdir+"bach.result", "title")

    puts "Details: query=together+by+youngbloods&rules.rulebase=common"
    assert_result("query=together+by+youngbloods&rules.rulebase=common",
                  selfdir+"youngbloods.result", "title")

    puts "Details: query=various&rules.rulebase=common&hits=9"
    assert_result("query=various&rules.rulebase=common&hits=9",
                  selfdir+"various.result", "title")

    # Removing two long stopword not using fsa (inheritance), and another using fsa (different rule)
    puts "Details: query=bahc+someotherlongstopword+somelongstopword+the&hits=8&rules.rulebase=egyik"
    assert_result("query=bahc+someotherlongstopword+somelongstopword+the&hits=8&rules.rulebase=egyik",
                  selfdir+"bach.result", "title")

    puts "Details: query=bahc+in+at+the+of&hits=8&rules.rulebase=egyik"
    assert_result("query=bahc+in+at+the+of&hits=8&rules.rulebase=egyik",
                  selfdir+"bach.result", "title")

    puts "Details: query=bahc+etaoin&hits=8&rules.rulebase=masik"
    assert_result("query=bahc+etaoin&hits=8&rules.rulebase=masik",
                  selfdir+"bach.result", "title")

    puts "Details: query=%E7%B4%A2%E5%B0%BC&rules.rulebase=cjk"
    # The above two chinese characters should be recognized as a brand by the cjk rule base
    assert_result("%E7%B4%A2%E5%B0%BC&rules.rulebase=cjk", selfdir+"cjk.result")
    result = search("%E7%B4%A2%E5%B0%BC&rules.rulebase=cjk&tracelevel=1")
    # The above two chinese characters should be recognized as a brand by the cjk rule base
    # (they are the encoding of the first brand in the brand list in that rule base):
    assert (result.xmldata.include? "brand:")

  end

  def teardown
    vespa.container.each_value do |qrs|
      qrs.removefile(Environment.instance.vespa_home + "/etc/vespa/fsa/stopwords.fsa")
    end
    stop
  end

end
