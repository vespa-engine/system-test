# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class IncludeInJdisc < SearchContainerTest
  
  def setup
      set_owner("musum")
      set_description("Verify that 'include' works under 'container', i.e. that component setup can be put in separate files.")
      add_bundle_dir(File.expand_path(selfdir), "mybundle")
      deploy(selfdir + "app")
      start
  end
  
  def test_include_in_jdisc    
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.xml", :cluster => "music")
    assert_hitcount("query=title:foo bar baz", 10)
  end
  
  def teardown
    stop
  end
  
end