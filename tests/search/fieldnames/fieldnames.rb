# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class Fieldnames < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def test_fieldnamewithunderscore
    feed_and_wait_for_docs("music", 2, :file => selfdir+"music.2.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 2)
  end


end
