# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class CloudAppOnSelfhosted < IndexedOnlySearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that this cloud sample app can be deployed on a self-hosted instance")
  end

  # Test a realistic setup
  def can_share_configservers?
    false
  end

  def test_cloud_app_on_selfhosted
    deploy(selfdir + "album-recommendation/")
    start
    feed_and_wait_for_docs("music", 1, :file => selfdir + "A-Head-Full-of-Dreams.json")
    assert_hitcount("?yql=select%20*%20from%20sources%20*%20where%20album%20contains%20%22head%22%3B", 1)
  end

  def teardown
    stop
  end

end
