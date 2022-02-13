# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class ImmediateFeeding < IndexedSearchTest

  def setup
    set_owner("valerijf")
    set_description("Tests that feeding immediately after vespa starts works. This testcase " +
                    "does not use any methods that sleeps or waits for services to start.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    vespa.start
  end

  def test_immediate_feeding
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.xml", :maxretries => "5")
    assert_result("query=sddocname:music", selfdir+"music.10.result.json", "title")
  end

  def teardown
    stop
  end

end
