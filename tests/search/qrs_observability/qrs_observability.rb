# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class QrsObservability < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json", :timeout => 240)
    wait_for_hitcount("sddocname:music", 10)
  end

  def test_result_includes_verbose_query_dump
    xml = search("ignored&tracelevel=10").xmldata
    arbitrary_part_query_dump = "WORD[connectedItem=null"
    assert(xml, xml.include?(arbitrary_part_query_dump) )
  end

    def qrs()
    vespa.container.values.first
  end


end
