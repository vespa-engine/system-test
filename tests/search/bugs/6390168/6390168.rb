# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Bug6390168 < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test bug 6390168")
  end

  def test_aba_in_array
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed(:file => selfdir+"feed.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:test", 1)
    assert_hitcount("query=sddocname:test", 1)
  end

  def teardown
    stop
  end

end
