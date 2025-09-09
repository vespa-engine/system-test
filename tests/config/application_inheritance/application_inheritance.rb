# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class ApplicationInheritance < IndexedOnlySearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests application inheritance")
  end

  # Otherwise VespaModel.resolve_app (called on deploy) will generate a hosts.xml file
  def can_share_configservers?
    false
  end

  # Test that feeding and querying the schema defined in the internal.text-search app works
  def test_application_inheritance
    deploy(selfdir + "inheriting-app/")
    start
    feed_and_wait_for_hitcount("query=hello", 1, :file => selfdir+"feed.jsonl")
  end

  def teardown
    stop
  end

end
