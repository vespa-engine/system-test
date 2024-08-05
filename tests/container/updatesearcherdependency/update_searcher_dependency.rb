# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class UpdateSearcherDependency < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Deploy a searcher and a class it depends on in different bundles, check update works.")
    @valgrind = false
  end

  def test_update_searcher_dependency
    dep1 = add_bundle_dir(selfdir+"initial", "com.yahoo.vespatest.Greeting",
                          {
                              :version=>"1.0.0",
                              :bundle_plugin_config =>"<useArtifactVersionForExportPackages>true</useArtifactVersionForExportPackages>",
                          })
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.testvespa.SimpleSearcher", :dependencies=>[dep1])
    deploy(selfdir+"app", SEARCH_DATA+"music.sd")
    start
    wait_for_hitcount("query=test",0)
    res = search("query=test&tracelevel=3")
    puts "Result from query=test:"
    puts res.xmldata
    assert_result("query=test", selfdir + "hello_world_result.json")

    # Re-deploy with same app, but modified searcher bundle dependency
    clear_bundles()
    dep2 = add_bundle_dir(selfdir+"updated", "com.yahoo.vespatest.Greeting",
                          {
                              :version=>"1.1.0",
                              :bundle_plugin_config =>"<useArtifactVersionForExportPackages>true</useArtifactVersionForExportPackages>",
                          })
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.testvespa.SimpleSearcher", :dependencies=>[dep2])
    deploy(selfdir + "app", SEARCH_DATA+"music.sd")
    poll_compare("test", selfdir + "new_world_result.json")
  end

  def teardown
    stop
  end

end
