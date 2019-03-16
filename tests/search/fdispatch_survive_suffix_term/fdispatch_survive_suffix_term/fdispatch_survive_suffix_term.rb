# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class FdispatchSurviveSuffixTerm < IndexedSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_fdispatch_survive_suffix_term
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.xml")
    assert_hitcount("query=*test&nocache", 5)
  end

  def teardown
    stop
  end

end
