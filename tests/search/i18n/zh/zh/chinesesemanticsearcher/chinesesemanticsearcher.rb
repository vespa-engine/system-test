# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# encoding: utf-8
require 'indexed_search_test'

class ChineseSemanticSearcher < IndexedSearchTest

    def setup
      set_owner("bratseth")
      set_description("CJK test for semantics module")
      deploy_app(SearchApp.new.sd(selfdir+"cjkrule.sd").rules_dir(selfdir+"rules"))
      start
    end

    def test_cjksemanticsearcher
        feed_and_wait_for_docs("cjkrule", 2, :file => selfdir+"cjkruledata.xml")

        lotr_filter = /Lord/
        puts "Detail: query=Lord of the ring"
        query = "query=Lord of the ring"
        assert_result_matches(query,selfdir+"lotr.result",lotr_filter)
        #save_result(query,selfdir+query)

        puts "Detail: query=Lord of the ring"
        query = "query=lotr"
        assert_result_matches(query,selfdir+"lotr.result",lotr_filter)
        #save_result(query,selfdir+query)

        potato_filter = /马铃薯/
        #query with there charater format of potato
        query = "query=%E9%A9%AC%E9%93%83%E8%96%AF&language=zh-hans"
        assert_result_matches(query,selfdir+"potato.result",potato_filter)
        #save_result(query,selfdir+query)

        #query with there charater format of potato
        query = "query=%E5%9C%9F%E8%B1%86&language=zh-hans"
        assert_result_matches(query,selfdir+"potato.result",potato_filter)
        #save_result(query,selfdir+query)

    end

    def teardown
    stop
    end
end
