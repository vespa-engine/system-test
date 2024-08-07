# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class ComponentVersion < SearchContainerTest
  def setup
    set_owner("gjoranv")
    set_description("Tests that different versions of bundles are supported.")
    add_version_test_bundle("1.0")
    add_version_test_bundle("1.0.1")
    deploy(selfdir+"app")
    start
  end

  def add_version_test_bundle(version)
    add_bundle_dir(File.expand_path(selfdir) + "/version-" + version.tr(".", "_"),
                        "com.yahoo.VersionTestSearcher", :version=>version)
  end

  def test_correct_searcher_used
    assert_version_called("1.0.1", "chain-1.0.1")
    assert_version_called("1.0.1", "chain-1.0")
    assert_version_called("1.0.0", "chain-1.0.0")
  end

  def assert_version_called(version, search_chain)
    result = search("&searchChain=#{search_chain}")
    title = result.hit[0].field["title"]
    assert_equal("Version #{version} of VersionTestSearcher", title)
  end

  def teardown
    stop
  end
end
