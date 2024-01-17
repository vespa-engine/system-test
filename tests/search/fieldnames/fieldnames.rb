# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class Fieldnames < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def test_fieldnamewithunderscore
    feed_and_wait_for_docs("music", 2, :file => selfdir+"music.2.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 2)
  end

  def teardown
    stop
  end

end
