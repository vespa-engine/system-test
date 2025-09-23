# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class WasFound < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Check that proton replies to updates and removes with " +
                    "the wasFound flag set correctly.")
  end

  def test_wasfound
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    tmpsource = dirs.tmpdir+File.basename(selfdir)
    vespa.adminserver.copy(selfdir+"project", tmpsource)
    install_maven_parent_pom(vespa.adminserver)
    vespa.adminserver.execute("cd #{tmpsource}; #{maven_command} test")
  end


end
