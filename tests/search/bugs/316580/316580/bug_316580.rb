# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Bug_316580 < IndexedSearchTest
  # Description: Bugfix for problem with long input without any spaces

  def nightly?
    true
  end

  def setup
    set_owner("aressem")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_input_without_space
    feed_and_wait_for_docs("music", 3, :file => selfdir+"bug316580.docs.3.xml")

    # Query: Ask for service, get 3 hits
    result = search("/?query=service")
    assert_equal(3, result.hitcount, "Query returned unexpected number of hits.")
  end

  def teardown
    stop
  end

end
