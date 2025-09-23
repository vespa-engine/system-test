# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class IncludeInDocproc < SearchContainerTest

  def timeout_seconds
    return 1600
  end

  def setup
    set_owner("gjoranv")
    set_description("Verify that 'include' works under 'document-processing', i.e. that docproc setup can be put in separate files.")
    add_bundle_dir(File.expand_path(selfdir), "mybundle")
    deploy(selfdir + "app")
    start
  end

  def test_include_in_docproc
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json", :cluster => "music")
    assert_result("query=sddocname:music", DOCPROC+"/data/music.10.result.json", "surl", ["title"])
  end


end
