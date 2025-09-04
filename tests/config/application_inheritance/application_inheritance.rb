# Copyright Vespa.ai. All rights reserved.
require 'search_test'
require 'indexed_only_search_test'

class ApplicationInheritance < IndexedOnlySearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests application inheritance")
  end

  # Test that feeding and querying the schema defined in the internal.text-search app works
  def test_application_inheritance
    deploy(selfdir + "inheriting-app/")
    start
    feed(:file => selfdir+"feed.json")
    assert_hitcount("query=hello", 1)
  end

  def teardown
    stop
  end

end
