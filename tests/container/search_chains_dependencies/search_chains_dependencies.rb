# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class SearchChainsDependencies < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Test that before/after for searchers and phases.")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.example.AddHitSearcher")
    deploy(selfdir+"app")
    start
  end

  def test_search_chains_depencencies
    # Inconsistencies between before/after semantics for searchers and phases will result in errors when starting the container.

    result = search("/search/?format=xml")
    titles = result.xml.get_elements("//hit//field[@name='title']")

    assert_equal("Added by s3", titles[0].text)
    assert_equal("Added by s2", titles[1].text)
    assert_equal("Added by s1", titles[2].text)
  end

  def teardown
    stop
  end

end
